"use server";

import { z } from "zod";
import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { requireActiveMembership, getAuthUser } from "@/lib/auth/session";
import type { ActionState } from "@/lib/actions/auth";

/** Sections a teacher may post to: ones they class-teach or teach a subject in. */
async function myTeacherSectionIds(
  supabase: Awaited<ReturnType<typeof createClient>>,
  schoolId: string,
  userId: string
): Promise<Set<string>> {
  const { data: staff } = await supabase
    .from("staff")
    .select("id")
    .eq("school_id", schoolId)
    .eq("user_id", userId)
    .maybeSingle();
  if (!staff) return new Set();
  const [{ data: ctSections }, { data: assignments }] = await Promise.all([
    supabase.from("sections").select("id").eq("class_teacher_staff_id", staff.id),
    supabase.from("teacher_assignments").select("section_id").eq("staff_id", staff.id),
  ]);
  return new Set([
    ...(ctSections ?? []).map((s) => s.id),
    ...(assignments ?? []).map((a) => a.section_id),
  ]);
}

const schema = z.object({
  title: z.string().trim().min(2, { error: "Enter a title." }),
  body: z.string().trim().min(2, { error: "Write the notice." }),
  audience: z.enum(["school", "class", "section", "individual"]),
  classId: z.string().uuid().optional().or(z.literal("")),
  sectionId: z.string().uuid().optional().or(z.literal("")),
  studentId: z.string().uuid().optional().or(z.literal("")),
  attachmentUrl: z.string().trim().optional(),
});

export async function createAnnouncement(
  _prev: ActionState,
  formData: FormData
): Promise<ActionState> {
  const membership = await requireActiveMembership();
  const user = await getAuthUser();
  if (!user) return { error: "You are not signed in." };
  const isAdmin = membership.role === "school_admin";

  const parsed = schema.safeParse({
    title: formData.get("title"),
    body: formData.get("body"),
    audience: formData.get("audience"),
    classId: formData.get("classId") ?? "",
    sectionId: formData.get("sectionId") ?? "",
    studentId: formData.get("studentId") ?? "",
    attachmentUrl: formData.get("attachmentUrl") ?? undefined,
  });
  if (!parsed.success) return { error: parsed.error.issues[0]?.message ?? "Invalid input." };
  const { title, body, audience, classId, sectionId, studentId, attachmentUrl } = parsed.data;

  const supabase = await createClient();
  const schoolId = membership.schoolId;

  // ---- authorize the audience + resolve the target ----
  if (audience === "school" || audience === "class") {
    if (!isAdmin) return { error: "Only admins can send school- or class-wide notices." };
    if (audience === "class" && !classId) return { error: "Choose a class." };
  } else if (audience === "section") {
    if (!sectionId) return { error: "Choose a section." };
    if (!isAdmin) {
      const mine = await myTeacherSectionIds(supabase, schoolId, user.id);
      if (!mine.has(sectionId)) return { error: "You can only post to your own sections." };
    }
  } else if (audience === "individual") {
    if (!studentId) return { error: "Choose a student." };
    if (!isAdmin) {
      // the student must be actively enrolled in one of the teacher's sections
      const mine = await myTeacherSectionIds(supabase, schoolId, user.id);
      const { data: enr } = await supabase
        .from("enrollments")
        .select("section_id")
        .eq("student_id", studentId)
        .eq("status", "active");
      if (!(enr ?? []).some((e) => mine.has(e.section_id))) {
        return { error: "You can only message students in your own sections." };
      }
    }
  }

  // ---- insert the announcement (RLS also blocks teachers from school/class) ----
  const { data: announcement, error } = await supabase
    .from("announcements")
    .insert({
      school_id: schoolId,
      created_by: user.id,
      audience,
      title,
      body,
      attachment_url: attachmentUrl || null,
    })
    .select("id")
    .single();

  if (error || !announcement) {
    return {
      error:
        error?.code === "42501" || (error && /row-level security/i.test(error.message))
          ? "You're not allowed to send this notice."
          : error?.message ?? "Could not post the notice.",
    };
  }

  // ---- target row (school-wide has none) ----
  if (audience !== "school") {
    const target: {
      announcement_id: string;
      school_id: string;
      class_id?: string;
      section_id?: string;
      student_id?: string;
    } = { announcement_id: announcement.id, school_id: schoolId };
    if (audience === "class") target.class_id = classId as string;
    if (audience === "section") target.section_id = sectionId as string;
    if (audience === "individual") target.student_id = studentId as string;

    const { error: tErr } = await supabase.from("announcement_targets").insert(target);
    if (tErr) {
      // roll back the orphaned announcement so we don't leave a target-less notice
      await supabase.from("announcements").delete().eq("id", announcement.id);
      return { error: tErr.message };
    }
  }

  revalidatePath("/notices");
  return { error: undefined };
}

export async function deleteAnnouncement(id: string): Promise<ActionState> {
  const membership = await requireActiveMembership();
  const supabase = await createClient();

  const { data: a } = await supabase
    .from("announcements")
    .select("attachment_url")
    .eq("id", id)
    .eq("school_id", membership.schoolId)
    .maybeSingle();

  const { error } = await supabase
    .from("announcements")
    .delete()
    .eq("id", id)
    .eq("school_id", membership.schoolId);
  if (error) return { error: error.message };

  if (a?.attachment_url) {
    await supabase.storage.from("notices").remove([a.attachment_url]);
  }

  revalidatePath("/notices");
  return { error: undefined };
}
