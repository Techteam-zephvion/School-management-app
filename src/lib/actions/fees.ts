"use server";

import { z } from "zod";
import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { requireActiveMembership, getAuthUser, type Membership } from "@/lib/auth/session";
import type { ActionState } from "@/lib/actions/auth";

async function requireAdmin(): Promise<{ membership: Membership } | { error: string }> {
  const membership = await requireActiveMembership();
  if (membership.role !== "school_admin") return { error: "Only school admins can manage fees." };
  return { membership };
}
function firstError(e: z.ZodError) {
  return e.issues[0]?.message ?? "Invalid input.";
}

// ---------------------------------------------------------------------------
// Fee structures + items
// ---------------------------------------------------------------------------
const structureSchema = z.object({
  name: z.string().trim().min(2, { error: "Name the fee, e.g. Term 1 Fees." }),
  classId: z.string().uuid().optional().or(z.literal("")),
  dueDate: z.string().min(1, { error: "Pick a due date." }),
});

export async function createStructure(_prev: ActionState, formData: FormData): Promise<ActionState> {
  const guard = await requireAdmin();
  if ("error" in guard) return guard;
  const parsed = structureSchema.safeParse({
    name: formData.get("name"),
    classId: formData.get("classId") ?? "",
    dueDate: formData.get("dueDate"),
  });
  if (!parsed.success) return { error: firstError(parsed.error) };

  const supabase = await createClient();
  const { data: activeYear } = await supabase
    .from("academic_years")
    .select("id")
    .eq("school_id", guard.membership.schoolId)
    .eq("is_active", true)
    .maybeSingle();
  if (!activeYear) return { error: "Set an active academic year first." };

  const { error } = await supabase.from("fee_structures").insert({
    school_id: guard.membership.schoolId,
    academic_year_id: activeYear.id,
    class_id: parsed.data.classId || null,
    name: parsed.data.name,
    due_date: parsed.data.dueDate,
  });
  if (error) return { error: error.message };
  revalidatePath("/settings/fees");
  return { error: undefined };
}

const itemSchema = z.object({
  structureId: z.string().uuid(),
  label: z.string().trim().min(1, { error: "Enter a label." }),
  amount: z.coerce.number().nonnegative({ error: "Amount can't be negative." }).max(10_000_000),
});

export async function addFeeItem(_prev: ActionState, formData: FormData): Promise<ActionState> {
  const guard = await requireAdmin();
  if ("error" in guard) return guard;
  const parsed = itemSchema.safeParse({
    structureId: formData.get("structureId"),
    label: formData.get("label"),
    amount: formData.get("amount"),
  });
  if (!parsed.success) return { error: firstError(parsed.error) };

  const supabase = await createClient();
  const { error } = await supabase.from("fee_items").insert({
    school_id: guard.membership.schoolId,
    fee_structure_id: parsed.data.structureId,
    label: parsed.data.label,
    amount: parsed.data.amount,
  });
  if (error) return { error: error.message };
  revalidatePath("/settings/fees");
  return { error: undefined };
}

export async function deleteFeeItem(id: string): Promise<ActionState> {
  const guard = await requireAdmin();
  if ("error" in guard) return guard;
  const supabase = await createClient();
  const { error } = await supabase.from("fee_items").delete().eq("id", id).eq("school_id", guard.membership.schoolId);
  if (error) return { error: error.message };
  revalidatePath("/settings/fees");
  return { error: undefined };
}

export async function deleteStructure(id: string): Promise<ActionState> {
  const guard = await requireAdmin();
  if ("error" in guard) return guard;
  const supabase = await createClient();
  const { error } = await supabase.from("fee_structures").delete().eq("id", id).eq("school_id", guard.membership.schoolId);
  if (error) return { error: error.message };
  revalidatePath("/settings/fees");
  return { error: undefined };
}

// ---------------------------------------------------------------------------
// Generate invoices for a structure
// ---------------------------------------------------------------------------
export async function generateInvoices(structureId: string): Promise<ActionState> {
  const guard = await requireAdmin();
  if ("error" in guard) return guard;
  const supabase = await createClient();
  const schoolId = guard.membership.schoolId;

  const { data: structure } = await supabase
    .from("fee_structures")
    .select("id, academic_year_id, class_id, total_amount, due_date")
    .eq("id", structureId)
    .eq("school_id", schoolId)
    .maybeSingle();
  if (!structure) return { error: "Fee structure not found." };
  if (Number(structure.total_amount) <= 0) return { error: "Add at least one fee item first." };

  // active-enrolled students in the applicable class (or all classes)
  const { data: enrollments } = await supabase
    .from("enrollments")
    .select("student_id, sections(class_id)")
    .eq("school_id", schoolId)
    .eq("academic_year_id", structure.academic_year_id)
    .eq("status", "active");

  const studentIds = (enrollments ?? [])
    .filter((e) => {
      if (!structure.class_id) return true;
      return (e.sections as { class_id: string } | null)?.class_id === structure.class_id;
    })
    .map((e) => e.student_id);
  if (studentIds.length === 0) return { error: "No enrolled students match this fee." };

  // skip students who already have an invoice for this structure
  const { data: existing } = await supabase
    .from("invoices")
    .select("student_id")
    .eq("fee_structure_id", structureId);
  const have = new Set((existing ?? []).map((i) => i.student_id));
  const toCreate = studentIds.filter((sid) => !have.has(sid));
  if (toCreate.length === 0) return { error: "Invoices already generated for all these students." };

  const { error } = await supabase.from("invoices").insert(
    toCreate.map((student_id) => ({
      school_id: schoolId,
      student_id,
      fee_structure_id: structureId,
      amount_total: structure.total_amount,
      due_date: structure.due_date,
    }))
  );
  if (error) return { error: error.message };
  revalidatePath("/settings/fees");
  return { error: undefined };
}

// ---------------------------------------------------------------------------
// Record an (offline) payment
// ---------------------------------------------------------------------------
const paymentSchema = z.object({
  invoiceId: z.string().uuid(),
  amount: z.coerce.number().positive({ error: "Enter an amount greater than 0." }),
  method: z.enum(["cash", "upi", "card", "bank", "offline"]),
});

export async function recordPayment(_prev: ActionState, formData: FormData): Promise<ActionState> {
  const guard = await requireAdmin();
  if ("error" in guard) return guard;
  const user = await getAuthUser();
  const parsed = paymentSchema.safeParse({
    invoiceId: formData.get("invoiceId"),
    amount: formData.get("amount"),
    method: formData.get("method"),
  });
  if (!parsed.success) return { error: firstError(parsed.error) };

  const supabase = await createClient();
  const { error } = await supabase.from("payments").insert({
    school_id: guard.membership.schoolId,
    invoice_id: parsed.data.invoiceId,
    amount: parsed.data.amount,
    method: parsed.data.method,
    status: "captured",
    recorded_by: user?.id ?? null,
  });
  if (error) {
    return {
      error: /exceeds the balance/i.test(error.message)
        ? "That payment is more than the remaining balance."
        : error.message,
    };
  }
  revalidatePath("/settings/fees");
  return { error: undefined };
}
