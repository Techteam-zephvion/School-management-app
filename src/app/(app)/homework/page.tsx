import Link from "next/link";
import { redirect } from "next/navigation";
import { BookOpen, CalendarClock, Paperclip } from "lucide-react";
import { requireActiveMembership, getAuthUser } from "@/lib/auth/session";
import { createClient } from "@/lib/supabase/server";
import { PageHeader } from "@/components/page-header";
import { Card, CardContent } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { CreateHomeworkDialog } from "./create-homework-dialog";

export type HomeworkTarget = {
  key: string;
  sectionId: string;
  subjectId: string;
  label: string;
};

function todayISO() {
  return new Date().toISOString().slice(0, 10);
}
function fmt(d: string) {
  return new Date(d + "T00:00:00").toLocaleDateString("en-IN", {
    day: "2-digit",
    month: "short",
    year: "numeric",
  });
}

export default async function HomeworkPage() {
  const membership = await requireActiveMembership();
  if (membership.role === "parent") redirect("/dashboard");
  const supabase = await createClient();
  const schoolId = membership.schoolId;
  const isAdmin = membership.role === "school_admin";

  const { data: activeYear } = await supabase
    .from("academic_years")
    .select("id")
    .eq("school_id", schoolId)
    .eq("is_active", true)
    .maybeSingle();

  // ---- assignable (section, subject) targets for this user ----
  const targets: HomeworkTarget[] = [];
  if (activeYear) {
    const [{ data: sections }, { data: subjects }, { data: classSubjects }] = await Promise.all([
      supabase
        .from("sections")
        .select("id, name, class_id, class_teacher_staff_id, classes(name)")
        .eq("school_id", schoolId)
        .eq("academic_year_id", activeYear.id)
        .order("name"),
      supabase.from("subjects").select("id, name").eq("school_id", schoolId),
      supabase.from("class_subjects").select("class_id, subject_id").eq("school_id", schoolId),
    ]);

    const subjectName = new Map((subjects ?? []).map((s) => [s.id, s.name]));
    const subsByClass = new Map<string, string[]>();
    for (const cs of classSubjects ?? []) {
      subsByClass.set(cs.class_id, [...(subsByClass.get(cs.class_id) ?? []), cs.subject_id]);
    }
    const label = (s: { name: string; classes: { name: string } | null }, subId: string) =>
      `${(s.classes as { name: string } | null)?.name ?? ""} · ${s.name} — ${subjectName.get(subId) ?? "Subject"}`;
    const seen = new Set<string>();
    const push = (sectionId: string, subjectId: string, lbl: string) => {
      const key = `${sectionId}:${subjectId}`;
      if (seen.has(key)) return;
      seen.add(key);
      targets.push({ key, sectionId, subjectId, label: lbl });
    };

    if (isAdmin) {
      for (const s of sections ?? [])
        for (const subId of subsByClass.get(s.class_id) ?? []) push(s.id, subId, label(s, subId));
    } else {
      const user = await getAuthUser();
      const { data: staff } = await supabase
        .from("staff")
        .select("id")
        .eq("school_id", schoolId)
        .eq("user_id", user?.id ?? "")
        .maybeSingle();
      if (staff) {
        // class teacher: any subject mapped to their section's class
        for (const s of sections ?? []) {
          if (s.class_teacher_staff_id === staff.id)
            for (const subId of subsByClass.get(s.class_id) ?? []) push(s.id, subId, label(s, subId));
        }
        // subject teacher: their exact assignments
        const { data: assignments } = await supabase
          .from("teacher_assignments")
          .select("section_id, subject_id")
          .eq("staff_id", staff.id)
          .eq("academic_year_id", activeYear.id);
        const sectionById = new Map((sections ?? []).map((s) => [s.id, s]));
        for (const a of assignments ?? []) {
          const s = sectionById.get(a.section_id);
          if (s) push(a.section_id, a.subject_id, label(s, a.subject_id));
        }
      }
    }
  }

  // ---- homework list (RLS scopes it: staff see all their school's) ----
  const { data: homework } = await supabase
    .from("homework")
    .select("id, title, due_date, attachment_url, sections(name, classes(name)), subjects(name)")
    .eq("school_id", schoolId)
    .order("due_date", { ascending: false });

  const today = todayISO();

  return (
    <div className="mx-auto max-w-7xl space-y-6">
      <PageHeader
        title="Homework"
        description="Assignments for your classes."
        action={
          targets.length > 0 ? (
            <CreateHomeworkDialog targets={targets} schoolId={schoolId} />
          ) : undefined
        }
      />

      {targets.length === 0 && membership.role !== "school_admin" && (
        <div className="flex items-start gap-3 rounded-2xl border border-amber-200/60 bg-amber-50/60 p-4">
          <span className="flex size-9 shrink-0 items-center justify-center rounded-xl bg-amber-100 text-amber-700 ring-1 ring-amber-200">
            <BookOpen className="size-4.5" />
          </span>
          <div className="min-w-0 flex-1 pt-0.5">
            <p className="text-sm font-medium text-amber-900">No classes assigned</p>
            <p className="mt-0.5 text-xs text-amber-700/80">
              You have no classes to assign homework for. A class teacher or subject teacher can post
              homework once assigned in Roles.
            </p>
          </div>
        </div>
      )}

      <Card className="overflow-hidden border border-slate-200/80 bg-white shadow-sm shadow-slate-950/5 ring-1 ring-slate-900/[0.02]">
        <div className="flex items-center gap-3 border-b border-slate-100 px-5 py-4">
          <span className="flex size-9 items-center justify-center rounded-xl bg-blue-50 text-blue-700 ring-1 ring-blue-100">
            <BookOpen className="size-4.5" />
          </span>
          <div>
            <h2 className="text-sm font-semibold text-slate-900">All homework</h2>
            <p className="text-xs text-slate-500">
              {homework?.length ?? 0} assignment{(homework?.length ?? 0) !== 1 ? "s" : ""}
            </p>
          </div>
        </div>
        <CardContent className="divide-y divide-slate-100 p-0">
          {!homework || homework.length === 0 ? (
            <div className="flex flex-col items-center gap-3 px-5 py-16 text-center">
              <span className="flex size-12 items-center justify-center rounded-2xl bg-slate-50 text-slate-400 ring-1 ring-slate-200">
                <BookOpen className="size-6" />
              </span>
              <div>
                <p className="text-sm font-medium text-slate-700">No homework posted yet</p>
                <p className="mt-0.5 text-xs text-slate-500">Assignments will appear here once posted.</p>
              </div>
            </div>
          ) : (
            homework.map((h) => {
              const section = h.sections as { name: string; classes: { name: string } | null } | null;
              const overdue = h.due_date < today;
              return (
                <Link
                  key={h.id}
                  href={`/homework/${h.id}`}
                  className="group flex items-center gap-4 px-5 py-4 transition-colors hover:bg-blue-50/60"
                >
                  <span className="flex size-10 shrink-0 items-center justify-center rounded-xl bg-blue-50 text-blue-700 ring-1 ring-blue-100 transition-colors group-hover:bg-blue-100">
                    <BookOpen className="size-5" />
                  </span>
                  <div className="min-w-0 flex-1">
                    <p className="flex items-center gap-1.5 truncate text-sm font-semibold text-slate-900">
                      {h.title}
                      {h.attachment_url && <Paperclip className="size-3.5 shrink-0 text-slate-400" />}
                    </p>
                    <p className="mt-0.5 truncate text-xs text-slate-500">
                      {section?.classes?.name} · {section?.name} ·{" "}
                      {(h.subjects as { name: string } | null)?.name}
                    </p>
                  </div>
                  <Badge
                    variant={overdue ? "destructive" : "secondary"}
                    className="shrink-0 gap-1.5 px-2.5 py-1 text-xs font-medium"
                  >
                    <CalendarClock className="size-3" />
                    {overdue ? "Overdue" : "Due"} {fmt(h.due_date)}
                  </Badge>
                </Link>
              );
            })
          )}
        </CardContent>
      </Card>
    </div>
  );
}
