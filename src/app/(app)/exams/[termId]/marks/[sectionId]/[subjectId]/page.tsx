import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { ArrowLeft, Info } from "lucide-react";
import { requireActiveMembership, getAuthUser } from "@/lib/auth/session";
import { createClient } from "@/lib/supabase/server";
import { Card, CardContent } from "@/components/ui/card";
import { MarksGrid } from "./marks-grid";

export default async function MarksEntryPage({
  params,
}: {
  params: Promise<{ termId: string; sectionId: string; subjectId: string }>;
}) {
  const { termId, sectionId, subjectId } = await params;
  const membership = await requireActiveMembership();
  if (membership.role === "parent") redirect("/dashboard");
  const supabase = await createClient();
  const schoolId = membership.schoolId;
  const isAdmin = membership.role === "school_admin";

  const [{ data: term }, { data: section }] = await Promise.all([
    supabase.from("exam_terms").select("id, name, academic_year_id, is_published").eq("id", termId).eq("school_id", schoolId).maybeSingle(),
    supabase
      .from("sections")
      .select("id, name, class_id, classes(name)")
      .eq("id", sectionId)
      .eq("school_id", schoolId)
      .maybeSingle(),
  ]);
  if (!term || !section) notFound();

  // Authorize: admin, or a teacher assigned to this subject in this section.
  if (!isAdmin) {
    const user = await getAuthUser();
    const { data: staff } = await supabase
      .from("staff")
      .select("id")
      .eq("school_id", schoolId)
      .eq("user_id", user?.id ?? "")
      .maybeSingle();
    const { data: assignment } = staff
      ? await supabase
          .from("teacher_assignments")
          .select("id")
          .eq("staff_id", staff.id)
          .eq("section_id", sectionId)
          .eq("subject_id", subjectId)
          .maybeSingle()
      : { data: null };
    if (!assignment) redirect(`/exams/${termId}`);
  }

  const [{ data: examSubject }, { data: subject }] = await Promise.all([
    supabase
      .from("exam_subjects")
      .select("id, max_marks")
      .eq("term_id", termId)
      .eq("class_id", section.class_id)
      .eq("subject_id", subjectId)
      .maybeSingle(),
    supabase.from("subjects").select("name").eq("id", subjectId).maybeSingle(),
  ]);

  const sectionLabel = `${(section.classes as { name: string } | null)?.name ?? ""} · ${section.name}`;
  const backLink = (
    <Link
      href={`/exams/${termId}`}
      className="inline-flex items-center gap-1.5 text-sm font-medium text-slate-500 transition-colors hover:text-slate-900"
    >
      <ArrowLeft className="size-4" /> {term.name}
    </Link>
  );

  if (!examSubject) {
    return (
      <div className="mx-auto max-w-4xl space-y-6 pb-8">
        {backLink}
        <div className="flex items-start gap-3 rounded-2xl border border-amber-200/80 bg-gradient-to-br from-amber-50 to-white px-5 py-4 shadow-sm shadow-slate-950/5">
          <span className="flex size-10 shrink-0 items-center justify-center rounded-2xl bg-amber-50 text-amber-700 ring-1 ring-amber-100">
            <Info className="size-5" />
          </span>
          <div className="min-w-0">
            <p className="text-sm font-medium text-amber-900">Subject not set up</p>
            <p className="mt-0.5 text-sm text-amber-700">
              {subject?.name ?? "This subject"} isn&apos;t set up for this class in {term.name} yet.
              {isAdmin ? " Add it (with its max marks) on the term page." : " Ask your admin to add it."}
            </p>
          </div>
        </div>
      </div>
    );
  }

  const [{ data: enrollments }, { data: marks }, { data: gradeScale }] = await Promise.all([
    supabase
      .from("enrollments")
      .select("roll_no, students(id, first_name, last_name)")
      .eq("section_id", sectionId)
      .eq("academic_year_id", term.academic_year_id)
      .eq("status", "active"),
    supabase.from("marks").select("student_id, marks_obtained").eq("exam_subject_id", examSubject.id),
    supabase
      .from("grade_scales")
      .select("min_percent, grade_label")
      .eq("school_id", schoolId)
      .order("min_percent", { ascending: false }),
  ]);

  const marksByStudent = new Map((marks ?? []).map((m) => [m.student_id, Number(m.marks_obtained)]));
  const students = (enrollments ?? [])
    .map((e) => {
      const st = e.students as { id: string; first_name: string; last_name: string | null } | null;
      return st
        ? {
            id: st.id,
            name: `${st.first_name} ${st.last_name ?? ""}`.trim(),
            roll: e.roll_no,
            value: marksByStudent.has(st.id) ? marksByStudent.get(st.id)! : null,
          }
        : null;
    })
    .filter((s): s is NonNullable<typeof s> => s !== null)
    .sort((a, b) => a.name.localeCompare(b.name));    return (
    <div className="mx-auto max-w-4xl space-y-6 pb-8">
      {backLink}
      {students.length === 0 ? (
        <Card className="border border-slate-200/80 bg-white/95 shadow-sm shadow-slate-950/5 ring-1 ring-slate-900/[0.02]">
          <CardContent className="flex min-h-[180px] flex-col items-center justify-center gap-3 py-12 text-center">
            <span className="flex size-12 items-center justify-center rounded-2xl bg-white text-slate-500 ring-1 ring-slate-200">
              <Info className="size-5" />
            </span>
            <p className="text-sm text-slate-500">No students are enrolled in this section yet.</p>
          </CardContent>
        </Card>
      ) : (
        <MarksGrid
          termId={termId}
          examSubjectId={examSubject.id}
          maxMarks={Number(examSubject.max_marks)}
          title={`${sectionLabel} · ${subject?.name ?? "Subject"}`}
          subtitle={term.name}
          isPublished={term.is_published}
          gradeBands={(gradeScale ?? []).map((g) => ({ min: Number(g.min_percent), label: g.grade_label }))}
          students={students}
        />
      )}
    </div>
  );
}
