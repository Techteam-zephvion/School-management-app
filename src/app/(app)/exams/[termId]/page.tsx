import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { ArrowLeft, ChevronRight, ClipboardList } from "lucide-react";
import { requireActiveMembership, getAuthUser } from "@/lib/auth/session";
import { createClient } from "@/lib/supabase/server";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { TermAdminBar } from "./term-admin-bar";
import { ExamSubjectsCard } from "./exam-subjects-card";

type EntryTarget = {
  sectionId: string;
  subjectId: string;
  sectionLabel: string;
  subjectName: string;
  maxMarks: number;
  entered: number;
  total: number;
};

export default async function ExamTermPage({ params }: { params: Promise<{ termId: string }> }) {
  const { termId } = await params;
  const membership = await requireActiveMembership();
  if (membership.role === "parent") redirect("/dashboard");
  const supabase = await createClient();
  const schoolId = membership.schoolId;
  const isAdmin = membership.role === "school_admin";

  const { data: term } = await supabase
    .from("exam_terms")
    .select("id, name, is_published, academic_year_id")
    .eq("id", termId)
    .eq("school_id", schoolId)
    .maybeSingle();
  if (!term) notFound();

  const [{ data: sections }, { data: subjects }, { data: classSubjects }, { data: examSubjects }] =
    await Promise.all([
      supabase
        .from("sections")
        .select("id, name, class_id, class_teacher_staff_id, classes(name)")
        .eq("school_id", schoolId)
        .eq("academic_year_id", term.academic_year_id)
        .order("name"),
      supabase.from("subjects").select("id, name").eq("school_id", schoolId).order("name"),
      supabase.from("class_subjects").select("class_id, subject_id").eq("school_id", schoolId),
      supabase
        .from("exam_subjects")
        .select("id, class_id, subject_id, max_marks")
        .eq("term_id", termId),
    ]);

  const subjectName = new Map((subjects ?? []).map((s) => [s.id, s.name]));
  const sectionLabel = (s: { name: string; classes: { name: string } | null }) =>
    `${(s.classes as { name: string } | null)?.name ?? ""} · ${s.name}`;

  // Enrollments + existing marks for progress counts.
  const [{ data: enrollments }, { data: marks }] = await Promise.all([
    supabase
      .from("enrollments")
      .select("student_id, section_id")
      .eq("school_id", schoolId)
      .eq("academic_year_id", term.academic_year_id)
      .eq("status", "active"),
    supabase.from("marks").select("exam_subject_id, student_id").eq("term_id", termId),
  ]);
  const sectionOfStudent = new Map((enrollments ?? []).map((e) => [e.student_id, e.section_id]));
  const totalBySection = new Map<string, number>();
  for (const e of enrollments ?? [])
    totalBySection.set(e.section_id, (totalBySection.get(e.section_id) ?? 0) + 1);
  // entered count keyed by `${examSubjectId}:${sectionId}`
  const enteredCount = new Map<string, number>();
  for (const m of marks ?? []) {
    const sec = sectionOfStudent.get(m.student_id);
    if (!sec) continue;
    const key = `${m.exam_subject_id}:${sec}`;
    enteredCount.set(key, (enteredCount.get(key) ?? 0) + 1);
  }

  // Which (section, subject) can the current user enter marks for?
  let allowed: ((sectionId: string, subjectId: string) => boolean) | null = null;
  if (!isAdmin) {
    const user = await getAuthUser();
    const { data: staff } = await supabase
      .from("staff")
      .select("id")
      .eq("school_id", schoolId)
      .eq("user_id", user?.id ?? "")
      .maybeSingle();
    const pairs = new Set<string>();
    if (staff) {
      const { data: assignments } = await supabase
        .from("teacher_assignments")
        .select("section_id, subject_id")
        .eq("staff_id", staff.id)
        .eq("academic_year_id", term.academic_year_id);
      for (const a of assignments ?? []) pairs.add(`${a.section_id}:${a.subject_id}`);
    }
    allowed = (sectionId, subjectId) => pairs.has(`${sectionId}:${subjectId}`);
  }

  // Build entry targets: each exam subject × each section of its class.
  const sectionsByClass = new Map<string, typeof sections>();
  for (const s of sections ?? [])
    sectionsByClass.set(s.class_id, [...(sectionsByClass.get(s.class_id) ?? []), s]);

  const targets: EntryTarget[] = [];
  for (const es of examSubjects ?? []) {
    for (const s of sectionsByClass.get(es.class_id) ?? []) {
      if (allowed && !allowed(s.id, es.subject_id)) continue;
      targets.push({
        sectionId: s.id,
        subjectId: es.subject_id,
        sectionLabel: sectionLabel(s),
        subjectName: subjectName.get(es.subject_id) ?? "Subject",
        maxMarks: Number(es.max_marks),
        entered: enteredCount.get(`${es.id}:${s.id}`) ?? 0,
        total: totalBySection.get(s.id) ?? 0,
      });
    }
  }
  targets.sort((a, b) =>
    (a.sectionLabel + a.subjectName).localeCompare(b.sectionLabel + b.subjectName)
  );

  // Exam-subjects grouped by class for the admin setup card.
  const examSubjectsByClass = (examSubjects ?? []).map((es) => ({
    id: es.id,
    classId: es.class_id,
    subjectId: es.subject_id,
    subjectName: subjectName.get(es.subject_id) ?? "Subject",
    maxMarks: Number(es.max_marks),
  }));
  const classOptions = [...sectionsByClass.keys()].map((cid) => ({
    id: cid,
    name: (sections ?? []).find((s) => s.class_id === cid)?.classes
      ? ((sections ?? []).find((s) => s.class_id === cid)!.classes as { name: string }).name
      : "Class",
  }));
  const subjectsByClass = new Map<string, string[]>();
  for (const cs of classSubjects ?? [])
    subjectsByClass.set(cs.class_id, [...(subjectsByClass.get(cs.class_id) ?? []), cs.subject_id]);

  return (
    <div className="mx-auto max-w-3xl space-y-6">
      <Link
        href="/exams"
        className="inline-flex items-center gap-1.5 text-sm text-muted-foreground transition-colors hover:text-foreground"
      >
        <ArrowLeft className="size-4" /> All terms
      </Link>

      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="flex items-center gap-3">
          <h1 className="text-2xl font-bold tracking-tight">{term.name}</h1>
          <Badge variant={term.is_published ? "success" : "secondary"}>
            {term.is_published ? "Published" : "Draft"}
          </Badge>
        </div>
        {isAdmin && <TermAdminBar termId={term.id} isPublished={term.is_published} termName={term.name} />}
      </div>

      {isAdmin && (
        <ExamSubjectsCard
          termId={term.id}
          classes={classOptions.sort((a, b) => a.name.localeCompare(b.name))}
          subjectName={Object.fromEntries(subjectName)}
          subjectsByClass={Object.fromEntries(subjectsByClass)}
          examSubjects={examSubjectsByClass}
        />
      )}

      <Card className="overflow-hidden border-0 shadow-md shadow-muted-foreground/5 ring-1 ring-border/50">
        <CardHeader>
          <CardTitle className="text-base">Enter marks</CardTitle>
          <CardDescription>
            {isAdmin
              ? "Every section × subject in this term."
              : "The sections and subjects you teach."}
          </CardDescription>
        </CardHeader>
        <CardContent className="divide-y divide-border/60 p-0">
          {targets.length === 0 ? (
            <div className="flex flex-col items-center gap-3 py-12 text-center">
              <span className="flex size-12 items-center justify-center rounded-2xl bg-muted/60">
                <ClipboardList className="size-6 text-muted-foreground/70" />
              </span>
              <p className="text-sm font-medium text-muted-foreground">Nothing to mark yet.</p>
              <p className="text-xs text-muted-foreground/70">
                {isAdmin
                  ? "Add subjects with max marks above to open mark entry."
                  : "Marks entry appears once your admin adds your subject to this term."}
              </p>
            </div>
          ) : (
            targets.map((t) => {
              const complete = t.total > 0 && t.entered >= t.total;
              return (
                <Link
                  key={`${t.sectionId}:${t.subjectId}`}
                  href={`/exams/${term.id}/marks/${t.sectionId}/${t.subjectId}`}
                  className="group flex items-center gap-4 px-5 py-4 transition-all hover:bg-muted/40"
                >
                  <span className="flex size-10 shrink-0 items-center justify-center rounded-xl bg-primary/10 text-primary transition-colors group-hover:bg-primary/15">
                    <ClipboardList className="size-5" />
                  </span>
                  <div className="min-w-0 flex-1">
                    <p className="truncate text-sm font-semibold">
                      {t.sectionLabel} · {t.subjectName}
                    </p>
                    <p className="mt-0.5 truncate text-xs text-muted-foreground">
                      Max {t.maxMarks} · {t.entered}/{t.total} entered
                    </p>
                  </div>
                  <Badge
                    variant={complete ? "success" : t.entered > 0 ? "warning" : "secondary"}
                    className="px-2.5 py-1 text-xs font-medium"
                  >
                    {complete ? "Complete" : t.entered > 0 ? "In progress" : "Not started"}
                  </Badge>
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
