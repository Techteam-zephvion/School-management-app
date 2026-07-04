import Link from "next/link";
import { redirect } from "next/navigation";
import { ChevronRight, Users } from "lucide-react";
import { requireActiveMembership, getAuthUser } from "@/lib/auth/session";
import { createClient } from "@/lib/supabase/server";
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

  return (
    <div className="mx-auto max-w-4xl space-y-6">
      <PageHeader
        title="Students"
        description={`${students?.length ?? 0} students at ${membership.schoolName}.`}
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

      <Card>
        <CardContent className="divide-y divide-border p-0">
          {!students || students.length === 0 ? (
            <div className="flex flex-col items-center gap-2 py-12 text-center">
              <Users className="size-8 text-muted-foreground" />
              <p className="text-sm text-muted-foreground">
                No students yet.{canAdd ? " Add your first student above." : ""}
              </p>
            </div>
          ) : (
            students.map((s) => {
              const name = `${s.first_name} ${s.last_name ?? ""}`.trim();
              const section = sectionByStudent.get(s.id);
              const guardians = guardianCount.get(s.id) ?? 0;
              return (
                <Link
                  key={s.id}
                  href={`/students/${s.id}`}
                  className="flex items-center gap-3 px-4 py-3 transition-colors hover:bg-muted/50"
                >
                  <Avatar className="size-9">
                    <AvatarFallback>{initials(s.first_name, s.last_name)}</AvatarFallback>
                  </Avatar>
                  <div className="min-w-0 flex-1">
                    <p className="truncate font-medium">{name}</p>
                    <p className="truncate text-xs text-muted-foreground">
                      #{s.admission_no}
                      {section ? ` · ${section}` : " · Not enrolled"}
                    </p>
                  </div>
                  {guardians > 0 && (
                    <Badge variant="secondary" className="gap-1">
                      <Users className="size-3" /> {guardians}
                    </Badge>
                  )}
                  {s.status !== "active" && (
                    <Badge variant="warning" className="capitalize">
                      {s.status}
                    </Badge>
                  )}
                  <ChevronRight className="size-4 text-muted-foreground" />
                </Link>
              );
            })
          )}
        </CardContent>
      </Card>
    </div>
  );
}
