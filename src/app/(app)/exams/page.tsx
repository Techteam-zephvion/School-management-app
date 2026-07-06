import Link from "next/link";
import { redirect } from "next/navigation";
import { GraduationCap, ChevronRight, CheckCircle2, PencilLine, CalendarClock } from "lucide-react";
import { requireActiveMembership } from "@/lib/auth/session";
import { createClient } from "@/lib/supabase/server";
import { PageHeader } from "@/components/page-header";
import { Card, CardContent } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Alert, AlertDescription } from "@/components/ui/alert";
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
      <div className="mx-auto max-w-3xl space-y-6">
        <PageHeader title="Marks & Exams" description="Exam terms, mark entry and results." />
        <Alert className="border-amber-200/60 bg-amber-50/60 text-amber-900">
          <CalendarClock className="size-4 text-amber-600" />
          <AlertDescription>Set an active academic year and create sections first.</AlertDescription>
        </Alert>
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
    <div className="mx-auto max-w-3xl space-y-6">
      <PageHeader
        title="Marks & Exams"
        description={`Exam terms for ${activeYear.name}.`}
        action={isAdmin ? <CreateTermDialog /> : undefined}
      />

      <Card className="overflow-hidden border-0 shadow-md shadow-muted-foreground/5 ring-1 ring-border/50">
        <CardContent className="divide-y divide-border/60 p-0">
          {!terms || terms.length === 0 ? (
            <div className="flex flex-col items-center gap-3 py-16 text-center">
              <span className="flex size-12 items-center justify-center rounded-2xl bg-muted/60">
                <GraduationCap className="size-6 text-muted-foreground/70" />
              </span>
              <p className="text-sm font-medium text-muted-foreground">No exam terms yet.</p>
              <p className="text-xs text-muted-foreground/70">
                {isAdmin
                  ? "Create a term to start setting up subjects and marks."
                  : "Your admin will add exam terms here."}
              </p>
            </div>
          ) : (
            terms.map((t) => {
              const subjectCount = (t.exam_subjects as { id: string }[] | null)?.length ?? 0;
              return (
                <Link
                  key={t.id}
                  href={`/exams/${t.id}`}
                  className="group flex items-center gap-4 px-5 py-4 transition-all hover:bg-muted/40"
                >
                  <span className="flex size-10 shrink-0 items-center justify-center rounded-xl bg-primary/10 text-primary transition-colors group-hover:bg-primary/15">
                    <GraduationCap className="size-5" />
                  </span>
                  <div className="min-w-0 flex-1">
                    <p className="truncate text-sm font-semibold">{t.name}</p>
                    <p className="mt-0.5 truncate text-xs text-muted-foreground">
                      {subjectCount} {subjectCount === 1 ? "subject" : "subjects"} · created {fmt(t.created_at)}
                    </p>
                  </div>
                  {t.is_published ? (
                    <Badge variant="success" className="gap-1 px-2.5 py-1 text-xs font-medium">
                      <CheckCircle2 className="size-3" /> Published
                    </Badge>
                  ) : (
                    <Badge variant="secondary" className="gap-1 px-2.5 py-1 text-xs font-medium">
                      <PencilLine className="size-3" /> Draft
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
