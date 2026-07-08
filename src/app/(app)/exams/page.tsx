import Link from "next/link";
import { redirect } from "next/navigation";
import { GraduationCap, ChevronRight, CheckCircle2, PencilLine, CalendarClock } from "lucide-react";
import { requireActiveMembership } from "@/lib/auth/session";
import { createClient } from "@/lib/supabase/server";
import { PageHeader } from "@/components/page-header";
import { Card, CardContent } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { CreateTermDialog } from "./create-term-dialog";

function fmt(d: string) {
  return new Date(d).toLocaleDateString("en-IN", { day: "2-digit", month: "short", year: "numeric" });
}

export default async function ExamsPage() {
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
      <div className="mx-auto max-w-7xl space-y-6 pb-8">
        <PageHeader title="Marks & Exams" description="Exam terms, mark entry and results." />
        <div className="flex min-h-[180px] flex-col items-center justify-center gap-3 rounded-2xl border border-dashed border-slate-200 bg-slate-50/70 px-4 py-8 text-center">
          <span className="flex size-12 items-center justify-center rounded-2xl bg-white text-slate-500 ring-1 ring-slate-200">
            <CalendarClock className="size-5" />
          </span>
          <p className="max-w-xs text-sm text-slate-500">
            Set an active academic year and create sections first.
          </p>
        </div>
      </div>
    );
  }

  const { data: terms } = await supabase
    .from("exam_terms")
    .select("id, name, is_published, created_at, exam_subjects(id)")
    .eq("school_id", schoolId)
    .eq("academic_year_id", activeYear.id)
    .order("created_at", { ascending: false });

  return (
    <div className="mx-auto max-w-7xl space-y-6 pb-8">
      <PageHeader
        title="Marks & Exams"
        description={`Exam terms for ${activeYear.name}.`}
        action={isAdmin ? <CreateTermDialog /> : undefined}
      />

      <Card className="overflow-hidden border border-slate-200/80 bg-white/95 shadow-sm shadow-slate-950/5 ring-1 ring-slate-900/[0.02]">
        <CardContent className="p-0">
          {!terms || terms.length === 0 ? (
            <div className="flex min-h-[220px] flex-col items-center justify-center gap-3 px-4 py-12 text-center">
              <span className="flex size-12 items-center justify-center rounded-2xl bg-white text-slate-500 ring-1 ring-slate-200">
                <GraduationCap className="size-5" />
              </span>
              <div>
                <p className="text-sm font-medium text-slate-900">No exam terms yet</p>
                <p className="mt-0.5 text-xs text-slate-500">
                  {isAdmin
                    ? "Create a term to start setting up subjects and marks."
                    : "Your admin will add exam terms here."}
                </p>
              </div>
            </div>
          ) : (
            <div className="divide-y divide-slate-100">
              {terms.map((t, idx) => {
                const subjectCount = (t.exam_subjects as { id: string }[] | null)?.length ?? 0;
                return (
                  <Link
                    key={t.id}
                    href={`/exams/${t.id}`}
                    className="flex items-center gap-4 px-5 py-4 transition-colors hover:bg-blue-50/60 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-ring"
                  >
                    <span className="flex size-10 shrink-0 items-center justify-center rounded-2xl bg-blue-50 text-blue-700 ring-1 ring-blue-100">
                      <GraduationCap className="size-5" />
                    </span>
                    <div className="min-w-0 flex-1">
                      <div className="flex items-center gap-2">
                        <p className="truncate text-sm font-semibold text-slate-900">{t.name}</p>
                        {t.is_published ? (
                          <Badge variant="success" className="gap-1 text-[10px]">
                            <CheckCircle2 className="size-3" /> Published
                          </Badge>
                        ) : (
                          <Badge variant="secondary" className="gap-1 text-[10px]">
                            <PencilLine className="size-3" /> Draft
                          </Badge>
                        )}
                      </div>
                      <p className="mt-0.5 truncate text-xs text-slate-500">
                        {subjectCount} {subjectCount === 1 ? "subject" : "subjects"} · created{" "}
                        {fmt(t.created_at)}
                      </p>
                    </div>
                    <ChevronRight className="size-4 text-slate-400" />
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
