import Link from "next/link";
import { redirect } from "next/navigation";
import { ChevronRight, GraduationCap, Users } from "lucide-react";
import { requireActiveMembership, getAuthUser } from "@/lib/auth/session";
import { createClient } from "@/lib/supabase/server";
import { cn } from "@/lib/utils";
import { PageHeader } from "@/components/page-header";
import { Card, CardContent } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Avatar, AvatarFallback } from "@/components/ui/avatar";
import { AddStudentDialog } from "./add-student-dialog";

function initials(first: string, last: string | null) {
  return `${first[0] ?? ""}${last?.[0] ?? ""}`.toUpperCase() || "?";
}

export default async function StudentsPage() {
  const membership = await requireActiveMembership();
  if (membership.role === "parent") redirect("/dashboard");
  const supabase = await createClient();
  const schoolId = membership.schoolId;
  const isAdmin = membership.role === "school_admin";

  const { data: activeYear } = await supabase
    .from("academic_years")
    .select("id, name")
    .eq("school_id", schoolId)
    .eq("is_active", true)
    .maybeSingle();

  const [{ data: students }, { data: enrollments }, { data: guardianRows }, { data: sections }] =
    await Promise.all([
      supabase
        .from("students")
        .select("id, admission_no, first_name, last_name, gender, status")
        .eq("school_id", schoolId)
        .order("first_name"),
      activeYear
        ? supabase
            .from("enrollments")
            .select("student_id, roll_no, sections(name, classes(name))")
            .eq("school_id", schoolId)
            .eq("academic_year_id", activeYear.id)
            .eq("status", "active")
        : Promise.resolve({ data: [] as never[] }),
      supabase.from("student_guardians").select("student_id").eq("school_id", schoolId),
      activeYear
        ? supabase
            .from("sections")
            .select("id, name, class_teacher_staff_id, classes(name)")
            .eq("school_id", schoolId)
            .eq("academic_year_id", activeYear.id)
            .order("name")
        : Promise.resolve({
            data: [] as {
              id: string;
              name: string;
              class_teacher_staff_id: string | null;
              classes: { name: string } | null;
            }[],
          }),
    ]);

  const sectionByStudent = new Map<string, string>();
  for (const e of enrollments ?? []) {
    const s = e.sections as { name: string; classes: { name: string } | null } | null;
    sectionByStudent.set(e.student_id, `${s?.classes?.name ?? ""} · ${s?.name ?? ""}`);
  }
  const guardianCount = new Map<string, number>();
  for (const g of guardianRows ?? []) {
    guardianCount.set(g.student_id, (guardianCount.get(g.student_id) ?? 0) + 1);
  }

  const allSectionOptions = (sections ?? []).map((s) => ({
    id: s.id,
    label: `${(s.classes as { name: string } | null)?.name ?? ""} · ${s.name}`,
  }));

  // A class teacher may add students only into the section(s) they class-teach.
  let canAdd = isAdmin;
  let dialogSections = allSectionOptions;
  if (!isAdmin) {
    const user = await getAuthUser();
    const { data: staff } = await supabase
      .from("staff")
      .select("id")
      .eq("school_id", schoolId)
      .eq("user_id", user?.id ?? "")
      .maybeSingle();
    const mySectionIds = new Set(
      (sections ?? [])
        .filter((s) => staff && s.class_teacher_staff_id === staff.id)
        .map((s) => s.id)
    );
    dialogSections = allSectionOptions.filter((s) => mySectionIds.has(s.id));
    canAdd = mySectionIds.size > 0;
  }

  const totalStudents = students?.length ?? 0;
  const enrolledCount = enrollments?.length ?? 0;

  return (
    <div className="mx-auto max-w-7xl space-y-6 pb-8">
      <PageHeader
        title="Students"
        description={`${totalStudents} student${totalStudents !== 1 ? "s" : ""} enrolled at ${membership.schoolName}.`}
        action={
          canAdd ? (
            <AddStudentDialog
              sections={dialogSections}
              hasActiveYear={Boolean(activeYear)}
              sectionRequired={!isAdmin}
            />
          ) : undefined
        }
      />

      {/* Summary stat cards */}
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
        <div className="rounded-2xl border border-slate-200/80 bg-gradient-to-br from-blue-50 to-white p-4 shadow-sm shadow-slate-950/5">
          <div className="flex items-start justify-between gap-3">
            <div className="min-w-0">
              <p className="text-xs font-semibold uppercase tracking-wide text-slate-500">
                Total students
              </p>
              <p className="mt-1 truncate text-2xl font-bold text-slate-950">{totalStudents}</p>
              <p className="mt-1 truncate text-xs text-slate-500">Active school records</p>
            </div>
            <span className="flex size-11 shrink-0 items-center justify-center rounded-2xl bg-blue-50 text-blue-700 ring-1 ring-blue-100">
              <GraduationCap className="size-5" />
            </span>
          </div>
        </div>
        <div className="rounded-2xl border border-slate-200/80 bg-gradient-to-br from-emerald-50 to-white p-4 shadow-sm shadow-slate-950/5">
          <div className="flex items-start justify-between gap-3">
            <div className="min-w-0">
              <p className="text-xs font-semibold uppercase tracking-wide text-slate-500">
                Currently enrolled
              </p>
              <p className="mt-1 truncate text-2xl font-bold text-slate-950">{enrolledCount}</p>
              <p className="mt-1 truncate text-xs text-slate-500">
                {activeYear?.name ?? "No active year"}
              </p>
            </div>
            <span className="flex size-11 shrink-0 items-center justify-center rounded-2xl bg-emerald-50 text-emerald-700 ring-1 ring-emerald-100">
              <Users className="size-5" />
            </span>
          </div>
        </div>
      </div>

      {/* Students list */}
      <Card className="overflow-hidden border border-slate-200/80 bg-white/95 shadow-sm shadow-slate-950/5 ring-1 ring-slate-900/[0.02]">
        <CardContent className="p-0">
          {!students || students.length === 0 ? (
            <div className="flex min-h-[220px] flex-col items-center justify-center gap-3 px-4 py-12 text-center">
              <span className="flex size-12 items-center justify-center rounded-2xl bg-white text-slate-500 ring-1 ring-slate-200">
                <Users className="size-5" />
              </span>
              <div>
                <p className="text-sm font-medium text-slate-900">No students yet</p>
                <p className="mt-0.5 text-xs text-slate-500">
                  {canAdd ? "Add your first student to get started." : ""}
                </p>
              </div>
            </div>
          ) : (
            <div className="divide-y divide-slate-100">
              {students.map((s, idx) => {
                const name = `${s.first_name} ${s.last_name ?? ""}`.trim();
                const section = sectionByStudent.get(s.id);
                const guardians = guardianCount.get(s.id) ?? 0;
                return (
                  <Link
                    key={s.id}
                    href={`/students/${s.id}`}
                    className={cn(
                      "flex items-center gap-3 px-5 py-3.5 transition-colors hover:bg-blue-50/60 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-ring",
                      idx === 0 && "rounded-t-2xl"
                    )}
                  >
                    <Avatar className="size-10 ring-1 ring-blue-100">
                      <AvatarFallback className="bg-blue-50 text-sm font-semibold text-blue-700">
                        {initials(s.first_name, s.last_name)}
                      </AvatarFallback>
                    </Avatar>
                    <div className="min-w-0 flex-1">
                      <div className="flex items-center gap-2">
                        <p className="truncate text-sm font-semibold text-slate-900">{name}</p>
                        {s.status !== "active" && (
                          <Badge variant="warning" className="shrink-0 text-[10px] capitalize">
                            {s.status}
                          </Badge>
                        )}
                      </div>
                      <p className="mt-0.5 truncate text-xs text-slate-500">
                        <span className="font-medium text-slate-600">#{s.admission_no}</span>
                        {section ? (
                          <>
                            <span className="mx-1.5 text-slate-300">·</span>
                            {section}
                          </>
                        ) : (
                          <>
                            <span className="mx-1.5 text-slate-300">·</span>
                            <span className="text-amber-600">Not enrolled</span>
                          </>
                        )}
                      </p>
                    </div>
                    <div className="flex items-center gap-2.5">
                      {guardians > 0 && (
                        <Badge
                          variant="secondary"
                          className="gap-1 border-slate-200 bg-slate-50 text-xs font-medium text-slate-600"
                        >
                          <Users className="size-3" />
                          {guardians}
                        </Badge>
                      )}
                      <ChevronRight className="size-4 text-slate-400" />
                    </div>
                  </Link>
                );
              })}
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
