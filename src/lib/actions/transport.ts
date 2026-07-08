"use server";

import { z } from "zod";
import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { createAdminClient } from "@/lib/supabase/admin";
import { requireActiveMembership, getAuthUser, type Membership } from "@/lib/auth/session";
import type { ActionState } from "@/lib/actions/auth";

async function requireAdmin(): Promise<{ membership: Membership } | { error: string }> {
  const membership = await requireActiveMembership();
  if (membership.role !== "school_admin") return { error: "Only school admins can manage transport." };
  return { membership };
}

/** Roster changes (assign/remove) are allowed for an admin of the student's
 *  school, or the class teacher of the student's section — the latter only for
 *  their own class's students. Reads use the caller's RLS-scoped client so the
 *  class check can't be spoofed. */
async function authorizeRoster(studentId: string): Promise<{ schoolId: string } | { error: string }> {
  const membership = await requireActiveMembership();
  const supabase = await createClient();
  const { data: student } = await supabase.from("students").select("school_id").eq("id", studentId).maybeSingle();
  if (!student || student.school_id !== membership.schoolId) return { error: "Student not found." };
  if (membership.role === "school_admin") return { schoolId: membership.schoolId };
  if (membership.role === "teacher") {
    const user = await getAuthUser();
    const { data: staff } = await supabase
      .from("staff")
      .select("id")
      .eq("school_id", membership.schoolId)
      .eq("user_id", user?.id ?? "")
      .maybeSingle();
    if (staff) {
      const { data: sections } = await supabase.from("sections").select("id").eq("class_teacher_staff_id", staff.id);
      const secIds = (sections ?? []).map((s) => s.id);
      if (secIds.length) {
        const { data: enr } = await supabase
          .from("enrollments")
          .select("student_id")
          .in("section_id", secIds)
          .eq("student_id", studentId)
          .eq("status", "active");
        if ((enr ?? []).length) return { schoolId: membership.schoolId };
      }
    }
  }
  return { error: "Only the class teacher or an admin can change this student's bus." };
}
async function requireStaff(): Promise<{ membership: Membership } | { error: string }> {
  const membership = await requireActiveMembership();
  if (membership.role !== "school_admin" && membership.role !== "teacher") {
    return { error: "Only staff can share a bus location." };
  }
  return { membership };
}
function firstError(e: z.ZodError) {
  return e.issues[0]?.message ?? "Invalid input.";
}
async function activeYear(supabase: Awaited<ReturnType<typeof createClient>>, schoolId: string) {
  const { data } = await supabase
    .from("academic_years")
    .select("id, end_date")
    .eq("school_id", schoolId)
    .eq("is_active", true)
    .maybeSingle();
  return data;
}

/** Find (or lazily create) the auto-managed per-year "Transport" fee container.
 *  Its invoices carry per-student amounts, so it never holds fee_items. */
async function ensureTransportStructure(
  supabase: Awaited<ReturnType<typeof createClient>>,
  schoolId: string,
  yearId: string,
  dueDate: string
): Promise<string | null> {
  const { data: existing } = await supabase
    .from("fee_structures")
    .select("id")
    .eq("school_id", schoolId)
    .eq("academic_year_id", yearId)
    .eq("is_transport", true)
    .maybeSingle();
  if (existing) return existing.id;
  const { data: created } = await supabase
    .from("fee_structures")
    .insert({ school_id: schoolId, academic_year_id: yearId, name: "Transport", is_transport: true, due_date: dueDate })
    .select("id")
    .single();
  return created?.id ?? null;
}

// ---------------------------------------------------------------------------
// Routes
// ---------------------------------------------------------------------------
const routeSchema = z.object({
  id: z.string().uuid().optional().or(z.literal("")),
  name: z.string().trim().min(2, { error: "Name the route, e.g. North Line." }),
  feeAmount: z.coerce.number().min(0, { error: "Fee can't be negative." }),
  driverName: z.string().trim().optional(),
  driverPhone: z.string().trim().optional(),
  vehicleNo: z.string().trim().optional(),
  capacity: z.coerce.number().int().min(0).optional().or(z.literal("")),
  description: z.string().trim().optional(),
});

export async function saveRoute(_prev: ActionState, formData: FormData): Promise<ActionState> {
  const guard = await requireAdmin();
  if ("error" in guard) return guard;
  const parsed = routeSchema.safeParse({
    id: formData.get("id") ?? "",
    name: formData.get("name"),
    feeAmount: formData.get("feeAmount"),
    driverName: formData.get("driverName") ?? undefined,
    driverPhone: formData.get("driverPhone") ?? undefined,
    vehicleNo: formData.get("vehicleNo") ?? undefined,
    capacity: formData.get("capacity") ?? "",
    description: formData.get("description") ?? undefined,
  });
  if (!parsed.success) return { error: firstError(parsed.error) };
  const supabase = await createClient();
  const schoolId = guard.membership.schoolId;
  const row = {
    name: parsed.data.name,
    fee_amount: parsed.data.feeAmount,
    driver_name: parsed.data.driverName || null,
    driver_phone: parsed.data.driverPhone || null,
    vehicle_no: parsed.data.vehicleNo || null,
    capacity: parsed.data.capacity === "" ? null : Number(parsed.data.capacity),
    description: parsed.data.description || null,
  };

  if (parsed.data.id) {
    const { error } = await supabase.from("bus_routes").update(row).eq("id", parsed.data.id).eq("school_id", schoolId);
    if (error) return { error: error.message };
    // Fee changed → resync active riders' snapshots and their transport invoices.
    await syncRouteFee(supabase, schoolId, parsed.data.id, parsed.data.feeAmount);
  } else {
    const { error } = await supabase.from("bus_routes").insert({ school_id: schoolId, ...row });
    if (error) return { error: error.message };
  }
  revalidatePath("/transport");
  return { error: undefined };
}

/** Push a route's new fee onto every active rider's snapshot + transport invoice. */
async function syncRouteFee(
  supabase: Awaited<ReturnType<typeof createClient>>,
  schoolId: string,
  routeId: string,
  fee: number
) {
  const { data: riders } = await supabase
    .from("student_transport")
    .select("student_id")
    .eq("route_id", routeId)
    .eq("active", true);
  const ids = (riders ?? []).map((r) => r.student_id);
  if (ids.length === 0) return;
  await supabase.from("student_transport").update({ fee_amount: fee }).eq("route_id", routeId).eq("active", true);
  const year = await activeYear(supabase, schoolId);
  if (!year) return;
  const structureId = await ensureTransportStructure(supabase, schoolId, year.id, year.end_date);
  if (!structureId) return;
  await supabase.from("invoices").update({ amount_total: fee }).eq("fee_structure_id", structureId).in("student_id", ids);
}

export async function deleteRoute(id: string): Promise<ActionState> {
  const guard = await requireAdmin();
  if ("error" in guard) return guard;
  const supabase = await createClient();
  const schoolId = guard.membership.schoolId;
  // Drop each rider's unpaid transport invoice before the assignments cascade away.
  const { data: riders } = await supabase.from("student_transport").select("student_id").eq("route_id", id).eq("school_id", schoolId);
  for (const r of riders ?? []) await removeTransportInvoice(supabase, r.student_id);
  const { error } = await supabase.from("bus_routes").delete().eq("id", id).eq("school_id", schoolId);
  if (error) return { error: error.message };
  revalidatePath("/transport");
  return { error: undefined };
}

// ---------------------------------------------------------------------------
// Stops
// ---------------------------------------------------------------------------
const stopSchema = z.object({
  routeId: z.string().uuid({ error: "Choose a route." }),
  name: z.string().trim().min(1, { error: "Name the stop." }),
  seq: z.coerce.number().int().min(0).optional().or(z.literal("")),
  pickupTime: z.string().optional(),
});

export async function addStop(_prev: ActionState, formData: FormData): Promise<ActionState> {
  const guard = await requireAdmin();
  if ("error" in guard) return guard;
  const parsed = stopSchema.safeParse({
    routeId: formData.get("routeId"),
    name: formData.get("name"),
    seq: formData.get("seq") ?? "",
    pickupTime: formData.get("pickupTime") ?? undefined,
  });
  if (!parsed.success) return { error: firstError(parsed.error) };
  const supabase = await createClient();
  const { error } = await supabase.from("bus_stops").insert({
    school_id: guard.membership.schoolId,
    route_id: parsed.data.routeId,
    name: parsed.data.name,
    seq: parsed.data.seq === "" ? 0 : Number(parsed.data.seq),
    pickup_time: parsed.data.pickupTime || null,
  });
  if (error) return { error: error.message };
  revalidatePath("/transport");
  return { error: undefined };
}

export async function deleteStop(id: string): Promise<ActionState> {
  const guard = await requireAdmin();
  if ("error" in guard) return guard;
  const supabase = await createClient();
  const { error } = await supabase.from("bus_stops").delete().eq("id", id).eq("school_id", guard.membership.schoolId);
  if (error) return { error: error.message };
  revalidatePath("/transport");
  return { error: undefined };
}

// ---------------------------------------------------------------------------
// Roster (assign / remove) — drives the auto transport fee
// ---------------------------------------------------------------------------
const assignSchema = z.object({
  studentId: z.string().uuid({ error: "Choose a student." }),
  routeId: z.string().uuid({ error: "Choose a route." }),
  stopId: z.string().uuid().optional().or(z.literal("")),
});

export async function assignStudentToBus(_prev: ActionState, formData: FormData): Promise<ActionState> {
  const parsed = assignSchema.safeParse({
    studentId: formData.get("studentId"),
    routeId: formData.get("routeId"),
    stopId: formData.get("stopId") ?? "",
  });
  if (!parsed.success) return { error: firstError(parsed.error) };
  const auth = await authorizeRoster(parsed.data.studentId);
  if ("error" in auth) return auth;
  const schoolId = auth.schoolId;
  // Authorized above; use the service role for the writes since the fee invoice
  // and container are otherwise admin-only (a class teacher can't write them).
  const supabase = createAdminClient();

  const { data: route } = await supabase
    .from("bus_routes")
    .select("id, fee_amount")
    .eq("id", parsed.data.routeId)
    .eq("school_id", schoolId)
    .maybeSingle();
  if (!route) return { error: "Route not found." };
  const fee = Number(route.fee_amount);
  // If a stop was chosen it must belong to this route.
  if (parsed.data.stopId) {
    const { data: stop } = await supabase
      .from("bus_stops")
      .select("id")
      .eq("id", parsed.data.stopId)
      .eq("route_id", parsed.data.routeId)
      .maybeSingle();
    if (!stop) return { error: "That stop isn't on this route." };
  }

  const { error: assignErr } = await supabase.from("student_transport").upsert(
    {
      school_id: schoolId,
      student_id: parsed.data.studentId,
      route_id: parsed.data.routeId,
      stop_id: parsed.data.stopId || null,
      fee_amount: fee,
      active: true,
    },
    { onConflict: "student_id" }
  );
  if (assignErr) return { error: assignErr.message };

  // Auto-charge: upsert this student's Transport invoice at the route fee.
  const year = await activeYear(supabase, schoolId);
  if (year) {
    const structureId = await ensureTransportStructure(supabase, schoolId, year.id, year.end_date);
    if (structureId) {
      const { error: invErr } = await supabase.from("invoices").upsert(
        {
          school_id: schoolId,
          student_id: parsed.data.studentId,
          fee_structure_id: structureId,
          amount_total: fee,
          due_date: year.end_date,
        },
        { onConflict: "student_id,fee_structure_id" }
      );
      if (invErr) return { error: invErr.message };
    }
  }
  revalidatePath("/transport");
  revalidatePath("/settings/fees");
  return { error: undefined };
}

/** Delete the student's transport invoice, but only if nothing's been paid on it. */
async function removeTransportInvoice(supabase: Awaited<ReturnType<typeof createClient>>, studentId: string) {
  const { data: invs } = await supabase
    .from("invoices")
    .select("id, amount_paid, fee_structures!inner(is_transport)")
    .eq("student_id", studentId)
    .eq("fee_structures.is_transport", true);
  for (const inv of invs ?? []) {
    if (Number(inv.amount_paid) === 0) await supabase.from("invoices").delete().eq("id", inv.id);
  }
}

export async function removeStudentFromBus(studentId: string): Promise<ActionState> {
  const auth = await authorizeRoster(studentId);
  if ("error" in auth) return auth;
  const supabase = createAdminClient();
  await removeTransportInvoice(supabase, studentId);
  const { error } = await supabase.from("student_transport").delete().eq("student_id", studentId).eq("school_id", auth.schoolId);
  if (error) return { error: error.message };
  revalidatePath("/transport");
  revalidatePath("/settings/fees");
  return { error: undefined };
}

// ---------------------------------------------------------------------------
// Live location (driver-share page)
// ---------------------------------------------------------------------------
export async function updateBusLocation(
  routeId: string,
  lat: number,
  lng: number,
  heading?: number | null,
  speed?: number | null
): Promise<ActionState> {
  const guard = await requireStaff();
  if ("error" in guard) return guard;
  const supabase = await createClient();
  const schoolId = guard.membership.schoolId;
  const { data: route } = await supabase.from("bus_routes").select("id").eq("id", routeId).eq("school_id", schoolId).maybeSingle();
  if (!route) return { error: "Route not found." };
  const user = await getAuthUser();
  const { error } = await supabase.from("bus_locations").upsert(
    {
      route_id: routeId,
      school_id: schoolId,
      lat,
      lng,
      heading: heading ?? null,
      speed: speed ?? null,
      updated_by: user?.id ?? null,
      updated_at: new Date().toISOString(),
    },
    { onConflict: "route_id" }
  );
  if (error) return { error: error.message };
  return { error: undefined };
}
