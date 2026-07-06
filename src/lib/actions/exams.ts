"use server";

import { z } from "zod";
import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { requireActiveMembership, getAuthUser, type Membership } from "@/lib/auth/session";
import type { ActionState } from "@/lib/actions/auth";

async function requireAdmin(): Promise<{ membership: Membership } | { error: string }> {
  const membership = await requireActiveMembership();
  if (membership.role !== "school_admin") {
    return { error: "Only school admins can manage exams." };
  }
  return { membership };
}
function firstError(e: z.ZodError) {
  return e.issues[0]?.message ?? "Invalid input.";
}

// ---------------------------------------------------------------------------
// Terms
// ---------------------------------------------------------------------------
export async function createTerm(_prev: ActionState, formData: FormData): Promise<ActionState> {
  const guard = await requireAdmin();
  if ("error" in guard) return guard;
  const name = String(formData.get("name") ?? "").trim();
  if (name.length < 2) return { error: "Name the term, e.g. Term 1." };

  const supabase = await createClient();
  const { data: activeYear } = await supabase
    .from("academic_years")
    .select("id")
    .eq("school_id", guard.membership.schoolId)
    .eq("is_active", true)
    .maybeSingle();
  if (!activeYear) return { error: "Set an active academic year first." };

  const { error } = await supabase.from("exam_terms").insert({
    school_id: guard.membership.schoolId,
    academic_year_id: activeYear.id,
    name,
  });
  if (error) return { error: error.message };
  revalidatePath("/exams");
  return { error: undefined };
}

export async function setTermPublished(termId: string, published: boolean): Promise<ActionState> {
  const guard = await requireAdmin();
  if ("error" in guard) return guard;
  const supabase = await createClient();
  const { error } = await supabase
    .from("exam_terms")
    .update({ is_published: published, published_at: published ? new Date().toISOString() : null })
    .eq("id", termId)
    .eq("school_id", guard.membership.schoolId);
  if (error) return { error: error.message };
  revalidatePath("/exams");
  revalidatePath(`/exams/${termId}`);
  return { error: undefined };
}

export async function deleteTerm(termId: string): Promise<ActionState> {
  const guard = await requireAdmin();
  if ("error" in guard) return guard;
  const supabase = await createClient();
  const { error } = await supabase
    .from("exam_terms")
    .delete()
    .eq("id", termId)
    .eq("school_id", guard.membership.schoolId);
  if (error) return { error: error.message };
  revalidatePath("/exams");
  return { error: undefined };
}

// ---------------------------------------------------------------------------
// Exam subjects (subject + max marks for a class in a term)
// ---------------------------------------------------------------------------
const examSubjectSchema = z.object({
  termId: z.string().uuid(),
  classId: z.string().uuid({ error: "Choose a class." }),
  subjectId: z.string().uuid({ error: "Choose a subject." }),
  maxMarks: z.coerce.number().positive({ error: "Max marks must be greater than 0." }).max(1000),
});

export async function upsertExamSubject(_prev: ActionState, formData: FormData): Promise<ActionState> {
  const guard = await requireAdmin();
  if ("error" in guard) return guard;
  const parsed = examSubjectSchema.safeParse({
    termId: formData.get("termId"),
    classId: formData.get("classId"),
    subjectId: formData.get("subjectId"),
    maxMarks: formData.get("maxMarks"),
  });
  if (!parsed.success) return { error: firstError(parsed.error) };

  const supabase = await createClient();
  const { error } = await supabase.from("exam_subjects").upsert(
    {
      school_id: guard.membership.schoolId,
      term_id: parsed.data.termId,
      class_id: parsed.data.classId,
      subject_id: parsed.data.subjectId,
      max_marks: parsed.data.maxMarks,
    },
    { onConflict: "term_id,class_id,subject_id" }
  );
  if (error) return { error: error.message };
  revalidatePath(`/exams/${parsed.data.termId}`);
  return { error: undefined };
}

export async function deleteExamSubject(id: string, termId: string): Promise<ActionState> {
  const guard = await requireAdmin();
  if ("error" in guard) return guard;
  const supabase = await createClient();
  const { error } = await supabase
    .from("exam_subjects")
    .delete()
    .eq("id", id)
    .eq("school_id", guard.membership.schoolId);
  if (error) return { error: error.message };
  revalidatePath(`/exams/${termId}`);
  return { error: undefined };
}

// ---------------------------------------------------------------------------
// Marks (bulk save for one exam subject + section)
// ---------------------------------------------------------------------------
export async function saveMarks(input: {
  termId: string;
  examSubjectId: string;
  marks: { studentId: string; value: number | null }[];
}): Promise<ActionState> {
  const membership = await requireActiveMembership();
  const user = await getAuthUser();
  if (!user) return { error: "You are not signed in." };
  const supabase = await createClient();

  const toUpsert = input.marks
    .filter((m) => m.value !== null && !Number.isNaN(m.value))
    .map((m) => ({
      school_id: membership.schoolId,
      term_id: input.termId,
      exam_subject_id: input.examSubjectId,
      student_id: m.studentId,
      marks_obtained: m.value as number,
      entered_by: user.id,
    }));
  const toClear = input.marks.filter((m) => m.value === null).map((m) => m.studentId);

  if (toUpsert.length > 0) {
    const { error } = await supabase
      .from("marks")
      .upsert(toUpsert, { onConflict: "exam_subject_id,student_id" });
    if (error) {
      return {
        error:
          error.code === "42501" || /row-level security/i.test(error.message)
            ? "You're not allowed to enter marks for this subject."
            : /must be between/i.test(error.message)
              ? error.message // surface the bound message from the trigger
              : error.message,
      };
    }
  }
  if (toClear.length > 0) {
    const { error } = await supabase
      .from("marks")
      .delete()
      .eq("exam_subject_id", input.examSubjectId)
      .in("student_id", toClear);
    if (error) return { error: error.message };
  }

  revalidatePath(`/exams/${input.termId}`);
  return { error: undefined };
}
