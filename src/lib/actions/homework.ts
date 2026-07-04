"use server";

import { z } from "zod";
import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { requireActiveMembership, getAuthUser } from "@/lib/auth/session";
import type { ActionState } from "@/lib/actions/auth";

const homeworkSchema = z.object({
  sectionId: z.string().uuid({ error: "Choose a class." }),
  subjectId: z.string().uuid({ error: "Choose a subject." }),
  title: z.string().trim().min(2, { error: "Enter a title." }),
  description: z.string().trim().optional(),
  dueDate: z.string().min(1, { error: "Pick a due date." }),
  attachmentUrl: z.string().trim().optional(),
});

export async function createHomework(
  _prev: ActionState,
  formData: FormData
): Promise<ActionState> {
  const membership = await requireActiveMembership();
  const user = await getAuthUser();
  if (!user) return { error: "You are not signed in." };

  const parsed = homeworkSchema.safeParse({
    sectionId: formData.get("sectionId"),
    subjectId: formData.get("subjectId"),
    title: formData.get("title"),
    description: formData.get("description") ?? undefined,
    dueDate: formData.get("dueDate"),
    attachmentUrl: formData.get("attachmentUrl") ?? undefined,
  });
  if (!parsed.success) return { error: parsed.error.issues[0]?.message ?? "Invalid input." };

  const supabase = await createClient();

  // can_assign_homework() in RLS is the real gate; insert fails for the wrong
  // (section, subject). We surface a friendly message for that case.
  const { error } = await supabase.from("homework").insert({
    school_id: membership.schoolId,
    section_id: parsed.data.sectionId,
    subject_id: parsed.data.subjectId,
    created_by: user.id,
    title: parsed.data.title,
    description: parsed.data.description || null,
    due_date: parsed.data.dueDate,
    attachment_url: parsed.data.attachmentUrl || null,
  });

  if (error) {
    return {
      error:
        error.code === "42501" || /row-level security/i.test(error.message)
          ? "You're not allowed to assign homework for this class/subject."
          : error.message,
    };
  }

  revalidatePath("/homework");
  return { error: undefined };
}

export async function deleteHomework(id: string): Promise<ActionState> {
  const membership = await requireActiveMembership();
  const supabase = await createClient();

  const { data: hw } = await supabase
    .from("homework")
    .select("attachment_url")
    .eq("id", id)
    .eq("school_id", membership.schoolId)
    .maybeSingle();

  const { error } = await supabase
    .from("homework")
    .delete()
    .eq("id", id)
    .eq("school_id", membership.schoolId);
  if (error) return { error: error.message };

  // Best-effort cleanup of the attachment object.
  if (hw?.attachment_url) {
    await supabase.storage.from("homework").remove([hw.attachment_url]);
  }

  revalidatePath("/homework");
  return { error: undefined };
}
