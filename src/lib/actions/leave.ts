"use server";

import { z } from "zod";
import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { requireActiveMembership, getAuthUser } from "@/lib/auth/session";
import type { ActionState } from "@/lib/actions/auth";

const createSchema = z
  .object({
    studentId: z.string().uuid({ error: "Choose a student." }),
    fromDate: z.string().min(1, { error: "Pick a start date." }),
    toDate: z.string().min(1, { error: "Pick an end date." }),
    reason: z.string().trim().optional(),
  })
  .refine((v) => v.toDate >= v.fromDate, { error: "End date can't be before the start.", path: ["toDate"] });

/** Staff can record a leave a parent phoned in; the RN app lets parents file
 *  their own. RLS enforces who the requester may file for. */
export async function createLeave(_prev: ActionState, formData: FormData): Promise<ActionState> {
  const membership = await requireActiveMembership();
  if (membership.role === "parent") return { error: "Not allowed here." };
  const user = await getAuthUser();
  if (!user) return { error: "You are not signed in." };

  const parsed = createSchema.safeParse({
    studentId: formData.get("studentId"),
    fromDate: formData.get("fromDate"),
    toDate: formData.get("toDate"),
    reason: formData.get("reason") ?? undefined,
  });
  if (!parsed.success) return { error: parsed.error.issues[0]?.message ?? "Invalid input." };

  const supabase = await createClient();
  const { error } = await supabase.from("leave_requests").insert({
    school_id: membership.schoolId,
    student_id: parsed.data.studentId,
    requested_by: user.id,
    from_date: parsed.data.fromDate,
    to_date: parsed.data.toDate,
    reason: parsed.data.reason || null,
  });
  if (error) return { error: error.message };
  revalidatePath("/leave");
  return { error: undefined };
}

/** Approve or reject a request. On approval the apply_leave_excused trigger marks
 *  the student excused across the range. */
export async function reviewLeave(id: string, approve: boolean): Promise<ActionState> {
  const membership = await requireActiveMembership();
  if (membership.role === "parent") return { error: "Not allowed." };
  const user = await getAuthUser();
  const supabase = await createClient();

  const { error } = await supabase
    .from("leave_requests")
    .update({
      status: approve ? "approved" : "rejected",
      reviewed_by: user?.id ?? null,
      reviewed_at: new Date().toISOString(),
    })
    .eq("id", id)
    .eq("school_id", membership.schoolId);
  if (error) {
    return {
      error: /row-level security/i.test(error.message) || error.code === "42501"
        ? "Only the class teacher or an admin can review this request."
        : error.message,
    };
  }
  revalidatePath("/leave");
  revalidatePath("/attendance");
  return { error: undefined };
}

export async function deleteLeave(id: string): Promise<ActionState> {
  const membership = await requireActiveMembership();
  const supabase = await createClient();
  const { error } = await supabase.from("leave_requests").delete().eq("id", id).eq("school_id", membership.schoolId);
  if (error) return { error: error.message };
  revalidatePath("/leave");
  return { error: undefined };
}
