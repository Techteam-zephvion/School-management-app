"use server";

import { z } from "zod";
import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { requireActiveMembership, getAuthUser, type Membership } from "@/lib/auth/session";
import type { ActionState } from "@/lib/actions/auth";

async function requireAdmin(): Promise<
  { membership: Membership } | { error: string }
> {
  const membership = await requireActiveMembership();
  if (membership.role !== "school_admin") {
    return { error: "Only school admins can manage students." };
  }
  return { membership };
}

/** The section ids the current user is the class teacher of (empty for admins
 *  who go through the school-wide path). Used to scope class-teacher adds. */
async function myClassTeacherSectionIds(
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
  const { data: sections } = await supabase
    .from("sections")
    .select("id")
    .eq("class_teacher_staff_id", staff.id);
  return new Set((sections ?? []).map((s) => s.id));
}

function firstError(err: z.ZodError): string {
  return err.issues[0]?.message ?? "Invalid input.";
}

async function activeYearId(
  supabase: Awaited<ReturnType<typeof createClient>>,
  schoolId: string
): Promise<string | null> {
  const { data } = await supabase
    .from("academic_years")
    .select("id")
    .eq("school_id", schoolId)
    .eq("is_active", true)
    .maybeSingle();
  return data?.id ?? null;
}

// ---------------------------------------------------------------------------
// Create / update student
// ---------------------------------------------------------------------------
const studentSchema = z.object({
  admissionNo: z.string().trim().min(1, { error: "Enter an admission number." }),
  firstName: z.string().trim().min(1, { error: "Enter the first name." }),
  lastName: z.string().trim().optional(),
  dob: z.string().trim().optional(),
  gender: z.enum(["male", "female", "other"]).optional(),
  bloodGroup: z.string().trim().optional(),
  address: z.string().trim().optional(),
  sectionId: z.string().uuid().optional().or(z.literal("")),
  rollNo: z.string().trim().optional(),
});

export async function createStudent(
  _prev: ActionState,
  formData: FormData
): Promise<ActionState> {
  const membership = await requireActiveMembership();
  const user = await getAuthUser();
  if (!user) return { error: "You are not signed in." };
  const isAdmin = membership.role === "school_admin";

  const parsed = studentSchema.safeParse({
    admissionNo: formData.get("admissionNo") ?? undefined,
    firstName: formData.get("firstName") ?? undefined,
    lastName: formData.get("lastName") ?? undefined,
    dob: formData.get("dob") ?? undefined,
    gender: formData.get("gender") || undefined,
    bloodGroup: formData.get("bloodGroup") ?? undefined,
    address: formData.get("address") ?? undefined,
    sectionId: formData.get("sectionId") ?? "",
    rollNo: formData.get("rollNo") ?? undefined,
  });
  if (!parsed.success) return { error: firstError(parsed.error) };

  const supabase = await createClient();
  const schoolId = membership.schoolId;

  // Class teachers may add students, but only into a section they class-teach,
  // and a section is required for them (admins can add unenrolled students).
  if (!isAdmin) {
    const mySections = await myClassTeacherSectionIds(supabase, schoolId, user.id);
    if (mySections.size === 0) {
      return { error: "Only school admins or class teachers can add students." };
    }
    if (!parsed.data.sectionId) {
      return { error: "Choose the section to add this student to." };
    }
    if (!mySections.has(parsed.data.sectionId)) {
      return { error: "You can only add students to a section you are the class teacher of." };
    }
  }

  const { data: student, error } = await supabase
    .from("students")
    .insert({
      school_id: schoolId,
      admission_no: parsed.data.admissionNo,
      first_name: parsed.data.firstName,
      last_name: parsed.data.lastName || null,
      dob: parsed.data.dob || null,
      gender: parsed.data.gender ?? null,
      blood_group: parsed.data.bloodGroup || null,
      address: parsed.data.address || null,
    })
    .select("id")
    .single();

  if (error) {
    return {
      error:
        error.code === "23505"
          ? "That admission number is already taken."
          : error.message,
    };
  }

  // Optional immediate enrollment into a section.
  if (parsed.data.sectionId) {
    const yearId = await activeYearId(supabase, schoolId);
    if (yearId) {
      await supabase.from("enrollments").insert({
        school_id: schoolId,
        student_id: student.id,
        section_id: parsed.data.sectionId,
        academic_year_id: yearId,
        roll_no: parsed.data.rollNo || null,
      });
    }
  }

  revalidatePath("/students");
  revalidatePath("/dashboard");
  return { error: undefined };
}

const updateStudentSchema = z.object({
  studentId: z.string().uuid(),
  firstName: z.string().trim().min(1, { error: "Enter the first name." }),
  lastName: z.string().trim().optional(),
  dob: z.string().trim().optional(),
  gender: z.enum(["male", "female", "other"]).optional(),
  bloodGroup: z.string().trim().optional(),
  address: z.string().trim().optional(),
});

export async function updateStudent(
  _prev: ActionState,
  formData: FormData
): Promise<ActionState> {
  const parsed = updateStudentSchema.safeParse({
    studentId: formData.get("studentId"),
    firstName: formData.get("firstName"),
    lastName: formData.get("lastName"),
    dob: formData.get("dob"),
    gender: formData.get("gender") || undefined,
    bloodGroup: formData.get("bloodGroup"),
    address: formData.get("address"),
  });
  if (!parsed.success) return { error: firstError(parsed.error) };

  // Admin (any student) or the class teacher of the student's section.
  const guard = await guardManageStudent(parsed.data.studentId);
  if ("error" in guard) return guard;

  const supabase = await createClient();
  const { error } = await supabase
    .from("students")
    .update({
      first_name: parsed.data.firstName,
      last_name: parsed.data.lastName || null,
      dob: parsed.data.dob || null,
      gender: parsed.data.gender ?? null,
      blood_group: parsed.data.bloodGroup || null,
      address: parsed.data.address || null,
    })
    .eq("id", parsed.data.studentId)
    .eq("school_id", guard.schoolId);

  if (error) return { error: error.message };
  revalidatePath(`/students/${parsed.data.studentId}`);
  revalidatePath("/students");
  return { error: undefined };
}

// ---------------------------------------------------------------------------
// Enrollment
// ---------------------------------------------------------------------------
const enrollSchema = z.object({
  studentId: z.string().uuid(),
  sectionId: z.string().uuid({ error: "Choose a section." }),
  rollNo: z.string().trim().optional(),
});

export async function enrollStudent(
  _prev: ActionState,
  formData: FormData
): Promise<ActionState> {
  const guard = await requireAdmin();
  if ("error" in guard) return guard;

  const parsed = enrollSchema.safeParse({
    studentId: formData.get("studentId"),
    sectionId: formData.get("sectionId"),
    rollNo: formData.get("rollNo"),
  });
  if (!parsed.success) return { error: firstError(parsed.error) };

  const supabase = await createClient();
  const schoolId = guard.membership.schoolId;
  const yearId = await activeYearId(supabase, schoolId);
  if (!yearId) return { error: "Set an active academic year first." };

  // One active enrollment per student per year: retire any current one first.
  await supabase
    .from("enrollments")
    .update({ status: "inactive" })
    .eq("student_id", parsed.data.studentId)
    .eq("academic_year_id", yearId)
    .eq("status", "active");

  const { error } = await supabase.from("enrollments").insert({
    school_id: schoolId,
    student_id: parsed.data.studentId,
    section_id: parsed.data.sectionId,
    academic_year_id: yearId,
    roll_no: parsed.data.rollNo || null,
  });

  if (error) return { error: error.message };
  revalidatePath(`/students/${parsed.data.studentId}`);
  revalidatePath("/students");
  return { error: undefined };
}

// ---------------------------------------------------------------------------
// Guardians (invite the parent, then link)
// ---------------------------------------------------------------------------

/** Admin (any student) or a class teacher of the student's active section.
 *  Returns the school id to operate under, or an error message. */
async function guardManageStudent(
  studentId: string
): Promise<{ schoolId: string } | { error: string }> {
  const membership = await requireActiveMembership();
  const supabase = await createClient();
  const schoolId = membership.schoolId;

  if (membership.role === "school_admin") return { schoolId };

  const user = await getAuthUser();
  if (user) {
    const mySections = await myClassTeacherSectionIds(supabase, schoolId, user.id);
    if (mySections.size > 0) {
      const { data: enrollments } = await supabase
        .from("enrollments")
        .select("section_id")
        .eq("student_id", studentId)
        .eq("status", "active");
      if ((enrollments ?? []).some((e) => mySections.has(e.section_id))) {
        return { schoolId };
      }
    }
  }
  return {
    error: "Only an admin or this student's class teacher can manage guardians.",
  };
}

const guardianSchema = z.object({
  studentId: z.string().uuid(),
  fullName: z.string().trim().min(2, { error: "Enter the guardian's name." }),
  email: z.email({ error: "Enter a valid email address." }),
  relation: z.enum(["mother", "father", "guardian"], {
    error: "Choose a relation.",
  }),
  phone: z.string().trim().optional(),
});

export async function inviteGuardian(
  _prev: ActionState,
  formData: FormData
): Promise<ActionState> {
  const parsed = guardianSchema.safeParse({
    studentId: formData.get("studentId"),
    fullName: formData.get("fullName"),
    email: formData.get("email"),
    relation: formData.get("relation"),
    phone: formData.get("phone"),
  });
  if (!parsed.success) return { error: firstError(parsed.error) };

  const guard = await guardManageStudent(parsed.data.studentId);
  if ("error" in guard) return guard;

  const supabase = await createClient();
  const schoolId = guard.schoolId;

  // Create/attach the parent auth user + membership + invite email.
  const { data, error } = await supabase.functions.invoke("invite-user", {
    body: {
      schoolId,
      email: parsed.data.email,
      fullName: parsed.data.fullName,
      role: "parent",
      phone: parsed.data.phone || undefined,
    },
  });
  if (error || data?.error || !data?.userId) {
    return { error: data?.error ?? error?.message ?? "Could not invite guardian." };
  }

  // First guardian for a student is primary by default.
  const { count } = await supabase
    .from("student_guardians")
    .select("id", { count: "exact", head: true })
    .eq("student_id", parsed.data.studentId);

  const { error: linkError } = await supabase.from("student_guardians").insert({
    school_id: schoolId,
    student_id: parsed.data.studentId,
    guardian_user_id: data.userId as string,
    relation: parsed.data.relation,
    is_primary: (count ?? 0) === 0,
  });

  if (linkError) {
    return {
      error:
        linkError.code === "23505"
          ? "That guardian is already linked to this student."
          : linkError.message,
    };
  }

  revalidatePath(`/students/${parsed.data.studentId}`);
  return { error: undefined };
}

export async function removeGuardian(linkId: string): Promise<ActionState> {
  const membership = await requireActiveMembership();
  const supabase = await createClient();

  const { data: link } = await supabase
    .from("student_guardians")
    .select("student_id")
    .eq("id", linkId)
    .eq("school_id", membership.schoolId)
    .maybeSingle();
  if (!link) return { error: "Guardian link not found." };

  const guard = await guardManageStudent(link.student_id);
  if ("error" in guard) return guard;

  const { error } = await supabase
    .from("student_guardians")
    .delete()
    .eq("id", linkId)
    .eq("school_id", membership.schoolId);

  if (error) return { error: error.message };
  revalidatePath(`/students/${link.student_id}`);
  return { error: undefined };
}
