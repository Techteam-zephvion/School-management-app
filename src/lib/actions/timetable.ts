"use server";

import { z } from "zod";
import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { requireActiveMembership, getAuthUser, type Membership } from "@/lib/auth/session";
import type { ActionState } from "@/lib/actions/auth";

async function requireAdmin(): Promise<{ membership: Membership } | { error: string }> {
  const membership = await requireActiveMembership();
  if (membership.role !== "school_admin") return { error: "Only school admins can edit the timetable." };
  return { membership };
}
async function requireStaff(): Promise<{ membership: Membership } | { error: string }> {
  const membership = await requireActiveMembership();
  if (membership.role === "parent") return { error: "Not allowed." };
  return { membership };
}
function firstError(e: z.ZodError) {
  return e.issues[0]?.message ?? "Invalid input.";
}
async function activeYearId(supabase: Awaited<ReturnType<typeof createClient>>, schoolId: string) {
  const { data } = await supabase
    .from("academic_years")
    .select("id")
    .eq("school_id", schoolId)
    .eq("is_active", true)
    .maybeSingle();
  return data?.id ?? null;
}

// ---------------------------------------------------------------------------
// Periods
// ---------------------------------------------------------------------------
const periodSchema = z.object({
  sectionId: z.string().uuid({ error: "Choose a section." }),
  weekday: z.coerce.number().int().min(0).max(6),
  periodNo: z.coerce.number().int().min(1).max(12),
  subjectId: z.string().uuid({ error: "Choose a subject." }),
  staffId: z.string().uuid().optional().or(z.literal("")),
  startTime: z.string().optional(),
  endTime: z.string().optional(),
});

export async function addPeriod(_prev: ActionState, formData: FormData): Promise<ActionState> {
  const guard = await requireAdmin();
  if ("error" in guard) return guard;
  const parsed = periodSchema.safeParse({
    sectionId: formData.get("sectionId"),
    weekday: formData.get("weekday"),
    periodNo: formData.get("periodNo"),
    subjectId: formData.get("subjectId"),
    staffId: formData.get("staffId") ?? "",
    startTime: formData.get("startTime") ?? undefined,
    endTime: formData.get("endTime") ?? undefined,
  });
  if (!parsed.success) return { error: firstError(parsed.error) };

  const supabase = await createClient();
  const yearId = await activeYearId(supabase, guard.membership.schoolId);
  if (!yearId) return { error: "Set an active academic year first." };

  const { error } = await supabase.from("periods").upsert(
    {
      school_id: guard.membership.schoolId,
      section_id: parsed.data.sectionId,
      academic_year_id: yearId,
      weekday: parsed.data.weekday,
      period_no: parsed.data.periodNo,
      subject_id: parsed.data.subjectId,
      staff_id: parsed.data.staffId || null,
      start_time: parsed.data.startTime || null,
      end_time: parsed.data.endTime || null,
    },
    { onConflict: "section_id,academic_year_id,weekday,period_no" }
  );
  if (error) return { error: error.message };
  revalidatePath("/timetable");
  return { error: undefined };
}

export async function deletePeriod(id: string): Promise<ActionState> {
  const guard = await requireAdmin();
  if ("error" in guard) return guard;
  const supabase = await createClient();
  const { error } = await supabase.from("periods").delete().eq("id", id).eq("school_id", guard.membership.schoolId);
  if (error) return { error: error.message };
  revalidatePath("/timetable");
  return { error: undefined };
}

// ---------------------------------------------------------------------------
// Events / holidays
// ---------------------------------------------------------------------------
const eventSchema = z
  .object({
    title: z.string().trim().min(2, { error: "Name the event." }),
    startDate: z.string().min(1, { error: "Pick a start date." }),
    endDate: z.string().min(1, { error: "Pick an end date." }),
    isHoliday: z.boolean(),
    sectionId: z.string().uuid().optional().or(z.literal("")),
    description: z.string().trim().optional(),
  })
  .refine((v) => v.endDate >= v.startDate, { error: "End date can't be before the start.", path: ["endDate"] });

export async function addEvent(_prev: ActionState, formData: FormData): Promise<ActionState> {
  const guard = await requireStaff();
  if ("error" in guard) return guard;
  const parsed = eventSchema.safeParse({
    title: formData.get("title"),
    startDate: formData.get("startDate"),
    endDate: formData.get("endDate"),
    isHoliday: formData.get("isHoliday") === "on",
    sectionId: formData.get("sectionId") ?? "",
    description: formData.get("description") ?? undefined,
  });
  if (!parsed.success) return { error: firstError(parsed.error) };

  const supabase = await createClient();
  const user = await getAuthUser();
  const { error } = await supabase.from("events").insert({
    school_id: guard.membership.schoolId,
    title: parsed.data.title,
    description: parsed.data.description || null,
    start_date: parsed.data.startDate,
    end_date: parsed.data.endDate,
    is_holiday: parsed.data.isHoliday,
    section_id: parsed.data.sectionId || null,
    created_by: user?.id ?? null,
  });
  if (error) return { error: error.message };
  revalidatePath("/timetable");
  revalidatePath("/attendance");
  return { error: undefined };
}

export async function deleteEvent(id: string): Promise<ActionState> {
  const guard = await requireStaff();
  if ("error" in guard) return guard;
  const supabase = await createClient();
  const { error } = await supabase.from("events").delete().eq("id", id).eq("school_id", guard.membership.schoolId);
  if (error) return { error: error.message };
  revalidatePath("/timetable");
  revalidatePath("/attendance");
  return { error: undefined };
}
