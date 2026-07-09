import { redirect } from "next/navigation";
import { requireActiveMembership } from "@/lib/auth/session";
import { createClient } from "@/lib/supabase/server";
import { PageHeader } from "@/components/page-header";
import { CalendarClock } from "lucide-react";
import { ClassTeachers } from "./class-teachers";
import { SubjectTeachers } from "./subject-teachers";

export type StaffOption = { id: string; name: string };

function staffName(row: {
  id: string;
  profiles: { full_name: string | null; email: string | null } | null;
}): StaffOption {
  return {
    id: row.id,
    name: row.profiles?.full_name || row.profiles?.email || "Unnamed staff",
  };
}

export default async function RolesPage() {
  const membership = await requireActiveMembership();
  if (membership.role !== "school_admin") redirect("/dashboard");

  const supabase = await createClient();
  const schoolId = membership.schoolId;

  const { data: activeYear } = await supabase
    .from("academic_years")
    .select("id, name")
    .eq("school_id", schoolId)
    .eq("is_active", true)
    .maybeSingle();

  if (!activeYear) {
    return (
      <div className="mx-auto max-w-5xl space-y-6 pb-8">
        <PageHeader
          title="Roles"
          description="Assign class teachers and subject teachers."
        />
        <div className="flex items-start gap-4 rounded-2xl border border-amber-200/60 bg-amber-50/60 px-5 py-4">
          <span className="flex size-10 shrink-0 items-center justify-center rounded-xl bg-amber-100 text-amber-700 ring-1 ring-amber-200">
            <CalendarClock className="size-5" />
          </span>
          <div className="min-w-0 flex-1 pt-0.5">
            <p className="text-sm font-semibold text-amber-900">No active academic year</p>
            <p className="mt-0.5 text-xs text-amber-700/80">
              Set an active academic year and create sections first.
            </p>
          </div>
        </div>
      </div>
    );
  }

  const [
    { data: staffRows },
    { data: sections },
    { data: subjects },
    { data: classSubjects },
    { data: assignments },
  ] = await Promise.all([
    supabase
      .from("staff")
      .select("id, user_id, profiles(full_name, email)")
      .eq("school_id", schoolId)
      .eq("status", "active"),
    supabase
      .from("sections")
      .select("id, name, class_id, class_teacher_staff_id, classes(name)")
      .eq("school_id", schoolId)
      .eq("academic_year_id", activeYear.id)
      .order("name"),
    supabase.from("subjects").select("id, name").eq("school_id", schoolId).order("name"),
    supabase
      .from("class_subjects")
      .select("class_id, subject_id")
      .eq("school_id", schoolId),
    supabase
      .from("teacher_assignments")
      .select(
        "id, staff_id, section_id, subject_id, staff(profiles(full_name, email)), sections(name, classes(name)), subjects(name)"
      )
      .eq("school_id", schoolId)
      .eq("academic_year_id", activeYear.id),
  ]);

  // Only teachers are assignable as class/subject teachers -- exclude admins
  const { data: teacherMembers } = await supabase
    .from("school_members")
    .select("user_id")
    .eq("school_id", schoolId)
    .eq("role", "teacher");
  const teacherUserIds = new Set((teacherMembers ?? []).map((m) => m.user_id));
  const staff = (staffRows ?? [])
    .filter((s) => teacherUserIds.has(s.user_id))
    .map(staffName);

  const sectionRows = (sections ?? []).map((s) => ({
    id: s.id,
    classId: s.class_id,
    label: `${(s.classes as { name: string } | null)?.name ?? ""} · ${s.name}`,
    classTeacherStaffId: s.class_teacher_staff_id,
  }));

  const assignmentRows = (assignments ?? []).map((a) => {
    const staffProfile = (a.staff as { profiles: { full_name: string | null; email: string | null } | null } | null)?.profiles;
    const section = a.sections as { name: string; classes: { name: string } | null } | null;
    return {
      id: a.id,
      teacher: staffProfile?.full_name || staffProfile?.email || "Unnamed",
      section: `${section?.classes?.name ?? ""} · ${section?.name ?? ""}`,
      subject: (a.subjects as { name: string } | null)?.name ?? "",
    };
  });

  return (
    <div className="mx-auto max-w-5xl space-y-6 pb-8">
      <PageHeader
        title="Roles"
        description={`Class & subject teacher assignments for ${activeYear.name}.`}
      />
      <ClassTeachers sections={sectionRows} staff={staff} />
      <SubjectTeachers
        sections={sectionRows}
        subjects={subjects ?? []}
        classSubjects={classSubjects ?? []}
        staff={staff}
        assignments={assignmentRows}
      />
    </div>
  );
}
