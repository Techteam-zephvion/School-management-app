"use server";

import { z } from "zod";
import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { requireActiveMembership, type Membership } from "@/lib/auth/session";
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
  const guard = await requireAdmin();
  if ("error" in guard) return guard;

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
  const schoolId = guard.membership.schoolId;

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
  const guard = await requireAdmin();
  if ("error" in guard) return guard;

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
    .eq("school_id", guard.membership.schoolId);

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
  const guard = await requireAdmin();
  if ("error" in guard) return guard;

  const parsed = guardianSchema.safeParse({
    studentId: formData.get("studentId"),
    fullName: formData.get("fullName"),
    email: formData.get("email"),
    relation: formData.get("relation"),
    phone: formData.get("phone"),
  });
  if (!parsed.success) return { error: firstError(parsed.error) };

  const supabase = await createClient();
  const schoolId = guard.membership.schoolId;

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
  const guard = await requireAdmin();
  if ("error" in guard) return guard;

  const supabase = await createClient();
  const { data: link } = await supabase
    .from("student_guardians")
    .select("student_id")
    .eq("id", linkId)
    .eq("school_id", guard.membership.schoolId)
    .maybeSingle();

  const { error } = await supabase
    .from("student_guardians")
    .delete()
    .eq("id", linkId)
    .eq("school_id", guard.membership.schoolId);

  if (error) return { error: error.message };
  if (link) revalidatePath(`/students/${link.student_id}`);
  return { error: undefined };
}
