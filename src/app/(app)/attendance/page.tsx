import { redirect } from "next/navigation";
import { CalendarClock, ClipboardCheck } from "lucide-react";
import { requireActiveMembership, getAuthUser } from "@/lib/auth/session";
import { createClient } from "@/lib/supabase/server";
import { PageHeader } from "@/components/page-header";
import { Card, CardContent } from "@/components/ui/card";
import { Alert, AlertDescription } from "@/components/ui/alert";
import { AttendancePicker } from "./attendance-picker";
import { AttendanceGrid } from "./attendance-grid";
import type { AttendStatus } from "@/lib/actions/attendance";

type Target = { key: string; sectionId: string; subjectId: string | null; label: string };

function todayISO() {
  return new Date().toISOString().slice(0, 10);
}

export default async function AttendancePage({
  searchParams,
}: {
  searchParams: Promise<{ target?: string; date?: string }>;
}) {
  const sp = await searchParams;
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

  if (!activeYear) {
    return (
      <div className="mx-auto max-w-4xl space-y-6">
        <PageHeader title="Attendance" description="Mark daily and subject-wise attendance." />
        <Alert>
          <CalendarClock className="size-4" />
          <AlertDescription>Set an active academic year and create sections first.</AlertDescription>
        </Alert>
      </div>
    );
  }

  const [{ data: sections }, { data: subjects }] = await Promise.all([
    supabase
      .from("sections")
      .select("id, name, class_id, class_teacher_staff_id, classes(name)")
      .eq("school_id", schoolId)
      .eq("academic_year_id", activeYear.id)
      .order("name"),
    supabase.from("subjects").select("id, name").eq("school_id", schoolId),
  ]);

  const sectionById = new Map((sections ?? []).map((s) => [s.id, s]));
  const subjectName = new Map((subjects ?? []).map((s) => [s.id, s.name]));
  const sectionLabel = (s: { name: string; classes: { name: string } | null }) =>
    `${(s.classes as { name: string } | null)?.name ?? ""} · ${s.name}`;

  // ---- Build the list of (section, mode) cells this user may mark ----
  const targets: Target[] = [];
  const seen = new Set<string>();
  const push = (sectionId: string, subjectId: string | null, label: string) => {
    const key = `${sectionId}:${subjectId ?? ""}`;
    if (seen.has(key)) return;
    seen.add(key);
    targets.push({ key, sectionId, subjectId, label });
  };

  if (isAdmin) {
    const { data: classSubjects } = await supabase
      .from("class_subjects")
      .select("class_id, subject_id")
      .eq("school_id", schoolId);
    const subsByClass = new Map<string, string[]>();
    for (const cs of classSubjects ?? []) {
      subsByClass.set(cs.class_id, [...(subsByClass.get(cs.class_id) ?? []), cs.subject_id]);
    }
    for (const s of sections ?? []) {
      push(s.id, null, `${sectionLabel(s)} — Daily`);
      for (const subId of subsByClass.get(s.class_id) ?? []) {
        push(s.id, subId, `${sectionLabel(s)} — ${subjectName.get(subId) ?? "Subject"}`);
      }
    }
  } else {
    const user = await getAuthUser();
    const { data: staff } = await supabase
      .from("staff")
      .select("id")
      .eq("school_id", schoolId)
      .eq("user_id", user?.id ?? "")
      .maybeSingle();
    if (staff) {
      // Daily attendance for sections this teacher is the class teacher of.
      for (const s of sections ?? []) {
        if (s.class_teacher_staff_id === staff.id) push(s.id, null, `${sectionLabel(s)} — Daily`);
      }
      // Subject attendance for their subject assignments this year.
      const { data: assignments } = await supabase
        .from("teacher_assignments")
        .select("section_id, subject_id")
        .eq("staff_id", staff.id)
        .eq("academic_year_id", activeYear.id);
      for (const a of assignments ?? []) {
        const s = sectionById.get(a.section_id);
        if (s) push(a.section_id, a.subject_id, `${sectionLabel(s)} — ${subjectName.get(a.subject_id) ?? "Subject"}`);
      }
    }
  }

  const date = sp.date && /^\d{4}-\d{2}-\d{2}$/.test(sp.date) ? sp.date : todayISO();
  const selected = targets.find((t) => t.key === sp.target) ?? null;

  // ---- Load the roster + any existing marks for the selected cell ----
  let students: { id: string; name: string; status: AttendStatus | null }[] = [];
  if (selected) {
    const [{ data: enrollments }, existing] = await Promise.all([
      supabase
        .from("enrollments")
        .select("roll_no, students(id, first_name, last_name)")
        .eq("section_id", selected.sectionId)
        .eq("academic_year_id", activeYear.id)
        .eq("status", "active"),
      (async () => {
        let q = supabase
          .from("attendance")
          .select("student_id, status")
          .eq("section_id", selected.sectionId)
          .eq("date", date);
        q = selected.subjectId ? q.eq("subject_id", selected.subjectId) : q.is("subject_id", null);
        const { data } = await q;
        return new Map((data ?? []).map((a) => [a.student_id, a.status as AttendStatus]));
      })(),
    ]);

    students = (enrollments ?? [])
      .map((e) => {
        const st = e.students as { id: string; first_name: string; last_name: string | null } | null;
        return st
          ? {
              id: st.id,
              name: `${st.first_name} ${st.last_name ?? ""}`.trim(),
              status: existing.get(st.id) ?? null,
            }
          : null;
      })
      .filter((s): s is NonNullable<typeof s> => s !== null)
      .sort((a, b) => a.name.localeCompare(b.name));
  }

  return (
    <div className="mx-auto max-w-3xl space-y-6">
      <PageHeader title="Attendance" description="Mark daily and subject-wise attendance." />

      {targets.length === 0 ? (
        <Alert>
          <ClipboardCheck className="size-4" />
          <AlertDescription>
            You have no classes to mark attendance for. A class teacher marks daily attendance; a
            subject teacher marks their subject. Ask your admin to assign you in Roles.
          </AlertDescription>
        </Alert>
      ) : (
        <>
          <AttendancePicker targets={targets} selectedKey={selected?.key ?? ""} date={date} />

          {selected ? (
            students.length > 0 ? (
              <AttendanceGrid
                key={`${selected.key}:${date}`}
                sectionId={selected.sectionId}
                subjectId={selected.subjectId}
                date={date}
                label={selected.label}
                students={students}
              />
            ) : (
              <Card>
                <CardContent className="py-10 text-center text-sm text-muted-foreground">
                  No students are enrolled in this section yet.
                </CardContent>
              </Card>
            )
          ) : (
            <Card>
              <CardContent className="py-10 text-center text-sm text-muted-foreground">
                Choose a class and date above to start marking.
              </CardContent>
            </Card>
          )}
        </>
      )}
    </div>
  );
}
