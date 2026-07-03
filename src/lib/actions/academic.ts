"use server";

import { z } from "zod";
import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { requireActiveMembership, type Membership } from "@/lib/auth/session";
import type { ActionState } from "@/lib/actions/auth";

/** All academic-setup writes are school_admin-only (doc 01 §4). Returns the
 *  admin's membership, or an error state the caller can surface. */
async function requireAdmin(): Promise<
  { membership: Membership } | { error: string }
> {
  const membership = await requireActiveMembership();
  if (membership.role !== "school_admin") {
    return { error: "Only school admins can change academic settings." };
  }
  return { membership };
}

function firstError(err: z.ZodError): string {
  return err.issues[0]?.message ?? "Invalid input.";
}

// ---------------------------------------------------------------------------
// School profile
// ---------------------------------------------------------------------------
const schoolProfileSchema = z.object({
  name: z.string().min(2, { error: "Enter the school name." }),
  address: z.string().trim().optional(),
  city: z.string().trim().optional(),
  state: z.string().trim().optional(),
  pincode: z.string().trim().optional(),
  phone: z.string().trim().optional(),
  email: z
    .string()
    .trim()
    .refine((v) => v === "" || z.email().safeParse(v).success, {
      error: "Enter a valid email or leave blank.",
    })
    .optional(),
});

export async function updateSchoolProfile(
  _prev: ActionState,
  formData: FormData
): Promise<ActionState> {
  const guard = await requireAdmin();
  if ("error" in guard) return guard;

  const parsed = schoolProfileSchema.safeParse({
    name: formData.get("name"),
    address: formData.get("address"),
    city: formData.get("city"),
    state: formData.get("state"),
    pincode: formData.get("pincode"),
    phone: formData.get("phone"),
    email: formData.get("email"),
  });
  if (!parsed.success) return { error: firstError(parsed.error) };

  const supabase = await createClient();
  const { error } = await supabase
    .from("schools")
    .update({
      name: parsed.data.name,
      address: parsed.data.address || null,
      city: parsed.data.city || null,
      state: parsed.data.state || null,
      pincode: parsed.data.pincode || null,
      phone: parsed.data.phone || null,
      email: parsed.data.email || null,
    })
    .eq("id", guard.membership.schoolId);

  if (error) return { error: error.message };
  revalidatePath("/settings/school");
  revalidatePath("/dashboard");
  return { error: undefined };
}

// ---------------------------------------------------------------------------
// Academic years
// ---------------------------------------------------------------------------
const academicYearSchema = z
  .object({
    name: z.string().min(2, { error: "Name the year, e.g. 2025-26." }),
    startDate: z.string().min(1, { error: "Pick a start date." }),
    endDate: z.string().min(1, { error: "Pick an end date." }),
    isActive: z.boolean(),
  })
  .refine((v) => v.endDate > v.startDate, {
    error: "End date must be after the start date.",
    path: ["endDate"],
  });

export async function createAcademicYear(
  _prev: ActionState,
  formData: FormData
): Promise<ActionState> {
  const guard = await requireAdmin();
  if ("error" in guard) return guard;

  const parsed = academicYearSchema.safeParse({
    name: formData.get("name"),
    startDate: formData.get("startDate"),
    endDate: formData.get("endDate"),
    isActive: formData.get("isActive") === "on",
  });
  if (!parsed.success) return { error: firstError(parsed.error) };

  const supabase = await createClient();
  const { error } = await supabase.from("academic_years").insert({
    school_id: guard.membership.schoolId,
    name: parsed.data.name,
    start_date: parsed.data.startDate,
    end_date: parsed.data.endDate,
    is_active: parsed.data.isActive,
  });

  if (error) return { error: error.message };
  revalidatePath("/settings/school");
  revalidatePath("/dashboard");
  return { error: undefined };
}

export async function setActiveAcademicYear(yearId: string): Promise<ActionState> {
  const guard = await requireAdmin();
  if ("error" in guard) return guard;

  const supabase = await createClient();
  // one_active_year trigger deactivates the others in this school.
  const { error } = await supabase
    .from("academic_years")
    .update({ is_active: true })
    .eq("id", yearId)
    .eq("school_id", guard.membership.schoolId);

  if (error) return { error: error.message };
  revalidatePath("/settings/school");
  revalidatePath("/dashboard");
  return { error: undefined };
}

// ---------------------------------------------------------------------------
// Classes
// ---------------------------------------------------------------------------
const classSchema = z.object({
  name: z.string().min(1, { error: "Enter a class name, e.g. Grade 5." }),
  sortOrder: z.coerce.number().int().optional(),
});

export async function createClass(
  _prev: ActionState,
  formData: FormData
): Promise<ActionState> {
  const guard = await requireAdmin();
  if ("error" in guard) return guard;

  const parsed = classSchema.safeParse({
    name: formData.get("name"),
    sortOrder: formData.get("sortOrder") || undefined,
  });
  if (!parsed.success) return { error: firstError(parsed.error) };

  const supabase = await createClient();
  const { error } = await supabase.from("classes").insert({
    school_id: guard.membership.schoolId,
    name: parsed.data.name,
    sort_order: parsed.data.sortOrder ?? 0,
  });

  if (error) {
    return {
      error: error.code === "23505" ? "That class already exists." : error.message,
    };
  }
  revalidatePath("/settings/classes");
  return { error: undefined };
}

export async function deleteClass(classId: string): Promise<ActionState> {
  const guard = await requireAdmin();
  if ("error" in guard) return guard;

  const supabase = await createClient();
  const { error } = await supabase
    .from("classes")
    .delete()
    .eq("id", classId)
    .eq("school_id", guard.membership.schoolId);

  if (error) return { error: error.message };
  revalidatePath("/settings/classes");
  return { error: undefined };
}

// ---------------------------------------------------------------------------
// Subjects
// ---------------------------------------------------------------------------
const subjectSchema = z.object({
  name: z.string().min(1, { error: "Enter a subject name." }),
  code: z.string().trim().optional(),
});

export async function createSubject(
  _prev: ActionState,
  formData: FormData
): Promise<ActionState> {
  const guard = await requireAdmin();
  if ("error" in guard) return guard;

  const parsed = subjectSchema.safeParse({
    name: formData.get("name"),
    code: formData.get("code"),
  });
  if (!parsed.success) return { error: firstError(parsed.error) };

  const supabase = await createClient();
  const { error } = await supabase.from("subjects").insert({
    school_id: guard.membership.schoolId,
    name: parsed.data.name,
    code: parsed.data.code || null,
  });

  if (error) {
    return {
      error: error.code === "23505" ? "That subject already exists." : error.message,
    };
  }
  revalidatePath("/settings/classes");
  return { error: undefined };
}

export async function deleteSubject(subjectId: string): Promise<ActionState> {
  const guard = await requireAdmin();
  if ("error" in guard) return guard;

  const supabase = await createClient();
  const { error } = await supabase
    .from("subjects")
    .delete()
    .eq("id", subjectId)
    .eq("school_id", guard.membership.schoolId);

  if (error) return { error: error.message };
  revalidatePath("/settings/classes");
  return { error: undefined };
}

// ---------------------------------------------------------------------------
// Sections (need an active academic year to hang off)
// ---------------------------------------------------------------------------
const sectionSchema = z.object({
  classId: z.string().uuid({ error: "Choose a class." }),
  name: z.string().min(1, { error: "Enter a section name, e.g. A." }),
});

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

export async function createSection(
  _prev: ActionState,
  formData: FormData
): Promise<ActionState> {
  const guard = await requireAdmin();
  if ("error" in guard) return guard;

  const parsed = sectionSchema.safeParse({
    classId: formData.get("classId"),
    name: formData.get("name"),
  });
  if (!parsed.success) return { error: firstError(parsed.error) };

  const supabase = await createClient();
  const yearId = await activeYearId(supabase, guard.membership.schoolId);
  if (!yearId) {
    return { error: "Set an active academic year first (School Profile)." };
  }

  const { error } = await supabase.from("sections").insert({
    school_id: guard.membership.schoolId,
    class_id: parsed.data.classId,
    name: parsed.data.name,
    academic_year_id: yearId,
  });

  if (error) {
    return {
      error:
        error.code === "23505"
          ? "That section already exists for this class."
          : error.message,
    };
  }
  revalidatePath("/settings/classes");
  revalidatePath("/settings/roles");
  return { error: undefined };
}

export async function deleteSection(sectionId: string): Promise<ActionState> {
  const guard = await requireAdmin();
  if ("error" in guard) return guard;

  const supabase = await createClient();
  const { error } = await supabase
    .from("sections")
    .delete()
    .eq("id", sectionId)
    .eq("school_id", guard.membership.schoolId);

  if (error) return { error: error.message };
  revalidatePath("/settings/classes");
  revalidatePath("/settings/roles");
  return { error: undefined };
}

// ---------------------------------------------------------------------------
// class_subjects mapping (replace the full set for a class)
// ---------------------------------------------------------------------------
export async function updateClassSubjects(
  classId: string,
  subjectIds: string[]
): Promise<ActionState> {
  const guard = await requireAdmin();
  if ("error" in guard) return guard;

  const supabase = await createClient();
  const schoolId = guard.membership.schoolId;

  // Reconcile: delete rows no longer selected, insert newly selected ones.
  const { data: existing } = await supabase
    .from("class_subjects")
    .select("id, subject_id")
    .eq("class_id", classId)
    .eq("school_id", schoolId);

  const current = new Set((existing ?? []).map((r) => r.subject_id));
  const wanted = new Set(subjectIds);

  const toAdd = subjectIds.filter((id) => !current.has(id));
  const toRemove = (existing ?? []).filter((r) => !wanted.has(r.subject_id));

  if (toAdd.length > 0) {
    const { error } = await supabase.from("class_subjects").insert(
      toAdd.map((subject_id) => ({ school_id: schoolId, class_id: classId, subject_id }))
    );
    if (error) return { error: error.message };
  }
  if (toRemove.length > 0) {
    const { error } = await supabase
      .from("class_subjects")
      .delete()
      .in(
        "id",
        toRemove.map((r) => r.id)
      );
    if (error) return { error: error.message };
  }

  revalidatePath("/settings/classes");
  return { error: undefined };
}

// ---------------------------------------------------------------------------
// Staff details
// ---------------------------------------------------------------------------
const staffDetailsSchema = z.object({
  staffId: z.string().uuid(),
  designation: z.string().trim().optional(),
  employeeNo: z.string().trim().optional(),
});

export async function updateStaffDetails(
  _prev: ActionState,
  formData: FormData
): Promise<ActionState> {
  const guard = await requireAdmin();
  if ("error" in guard) return guard;

  const parsed = staffDetailsSchema.safeParse({
    staffId: formData.get("staffId"),
    designation: formData.get("designation"),
    employeeNo: formData.get("employeeNo"),
  });
  if (!parsed.success) return { error: firstError(parsed.error) };

  const supabase = await createClient();
  const { error } = await supabase
    .from("staff")
    .update({
      designation: parsed.data.designation || null,
      employee_no: parsed.data.employeeNo || null,
    })
    .eq("id", parsed.data.staffId)
    .eq("school_id", guard.membership.schoolId);

  if (error) return { error: error.message };
  revalidatePath("/settings/staff");
  return { error: undefined };
}

// ---------------------------------------------------------------------------
// Roles: class teacher + subject teacher assignments
// ---------------------------------------------------------------------------
export async function assignClassTeacher(
  sectionId: string,
  staffId: string | null
): Promise<ActionState> {
  const guard = await requireAdmin();
  if ("error" in guard) return guard;

  const supabase = await createClient();
  const { error } = await supabase
    .from("sections")
    .update({ class_teacher_staff_id: staffId })
    .eq("id", sectionId)
    .eq("school_id", guard.membership.schoolId);

  if (error) return { error: error.message };
  revalidatePath("/settings/roles");
  return { error: undefined };
}

const subjectTeacherSchema = z.object({
  staffId: z.string().uuid({ error: "Choose a teacher." }),
  sectionId: z.string().uuid({ error: "Choose a section." }),
  subjectId: z.string().uuid({ error: "Choose a subject." }),
});

export async function assignSubjectTeacher(
  _prev: ActionState,
  formData: FormData
): Promise<ActionState> {
  const guard = await requireAdmin();
  if ("error" in guard) return guard;

  const parsed = subjectTeacherSchema.safeParse({
    staffId: formData.get("staffId"),
    sectionId: formData.get("sectionId"),
    subjectId: formData.get("subjectId"),
  });
  if (!parsed.success) return { error: firstError(parsed.error) };

  const supabase = await createClient();
  const yearId = await activeYearId(supabase, guard.membership.schoolId);
  if (!yearId) return { error: "Set an active academic year first." };

  const { error } = await supabase.from("teacher_assignments").insert({
    school_id: guard.membership.schoolId,
    staff_id: parsed.data.staffId,
    section_id: parsed.data.sectionId,
    subject_id: parsed.data.subjectId,
    academic_year_id: yearId,
  });

  if (error) {
    return {
      error:
        error.code === "23505"
          ? "That teacher already teaches this subject in this section."
          : error.message,
    };
  }
  revalidatePath("/settings/roles");
  revalidatePath("/dashboard");
  return { error: undefined };
}

export async function removeSubjectTeacher(
  assignmentId: string
): Promise<ActionState> {
  const guard = await requireAdmin();
  if ("error" in guard) return guard;

  const supabase = await createClient();
  const { error } = await supabase
    .from("teacher_assignments")
    .delete()
    .eq("id", assignmentId)
    .eq("school_id", guard.membership.schoolId);

  if (error) return { error: error.message };
  revalidatePath("/settings/roles");
  revalidatePath("/dashboard");
  return { error: undefined };
}
