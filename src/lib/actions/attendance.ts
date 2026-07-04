"use server";

import { z } from "zod";
import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { requireActiveMembership, getAuthUser } from "@/lib/auth/session";
import type { ActionState } from "@/lib/actions/auth";
import type { Database } from "@/lib/supabase/database.types";

export type AttendStatus = Database["public"]["Enums"]["attend_status"];

const markSchema = z.object({
  sectionId: z.string().uuid(),
  date: z.string().min(1, { error: "Pick a date." }),
  subjectId: z.string().uuid().nullable(),
  marks: z
    .array(
      z.object({
        studentId: z.string().uuid(),
        status: z.enum(["present", "absent", "late", "excused", "holiday"]),
      })
    )
    .min(1, { error: "Nothing to save." }),
});

export async function saveAttendance(input: {
  sectionId: string;
  date: string;
  subjectId: string | null;
  marks: { studentId: string; status: AttendStatus }[];
}): Promise<ActionState> {
  const membership = await requireActiveMembership();
  const user = await getAuthUser();
  if (!user) return { error: "You are not signed in." };

  const parsed = markSchema.safeParse(input);
  if (!parsed.success) return { error: parsed.error.issues[0]?.message ?? "Invalid input." };
  const { sectionId, date, subjectId, marks } = parsed.data;

  const supabase = await createClient();

  // Confirm the section is in the caller's school (RLS also enforces this).
  const { data: section } = await supabase
    .from("sections")
    .select("school_id")
    .eq("id", sectionId)
    .maybeSingle();
  if (!section || section.school_id !== membership.schoolId) {
    return { error: "Section not found." };
  }

  // Replace the existing marks for this section/date/mode, then insert fresh.
  // Both statements are gated by can_mark_attendance() in RLS, so an
  // unauthorised caller clears nothing and the insert is rejected below.
  const del = supabase.from("attendance").delete().eq("section_id", sectionId).eq("date", date);
  const { error: delError } = await (subjectId
    ? del.eq("subject_id", subjectId)
    : del.is("subject_id", null));
  if (delError) return { error: delError.message };

  const { error: insError } = await supabase.from("attendance").insert(
    marks.map((m) => ({
      school_id: membership.schoolId,
      student_id: m.studentId,
      section_id: sectionId,
      date,
      subject_id: subjectId,
      status: m.status,
      marked_by: user.id,
    }))
  );
  if (insError) {
    return {
      error:
        insError.code === "42501" || /row-level security/i.test(insError.message)
          ? "You're not allowed to mark attendance for this class."
          : insError.message,
    };
  }

  revalidatePath("/attendance");
  return { error: undefined };
}
