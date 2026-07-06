import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { ArrowLeft, Info } from "lucide-react";
import { requireActiveMembership, getAuthUser } from "@/lib/auth/session";
import { createClient } from "@/lib/supabase/server";
import { Card, CardContent } from "@/components/ui/card";
import { Alert, AlertDescription } from "@/components/ui/alert";
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
      className="inline-flex items-center gap-1.5 text-sm text-muted-foreground transition-colors hover:text-foreground"
    >
      <ArrowLeft className="size-4" /> {term.name}
    </Link>
  );

  if (!examSubject) {
    return (
      <div className="mx-auto max-w-2xl space-y-6">
        {backLink}
        <Alert className="border-amber-200/60 bg-amber-50/60 text-amber-900">
          <Info className="size-4 text-amber-600" />
          <AlertDescription>
            {subject?.name ?? "This subject"} isn&apos;t set up for this class in {term.name} yet.
            {isAdmin ? " Add it (with its max marks) on the term page." : " Ask your admin to add it."}
          </AlertDescription>
        </Alert>
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
    .sort((a, b) => a.name.localeCompare(b.name));

  return (
    <div className="mx-auto max-w-2xl space-y-6">
      {backLink}
      {students.length === 0 ? (
        <Card className="border-0 shadow-md shadow-muted-foreground/5 ring-1 ring-border/50">
          <CardContent className="py-12 text-center text-sm text-muted-foreground">
            No students are enrolled in this section yet.
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
