import { redirect } from "next/navigation";
import { requireActiveMembership } from "@/lib/auth/session";
import { createClient } from "@/lib/supabase/server";
import { PageHeader } from "@/components/page-header";
import { CalendarClock } from "lucide-react";
import { SubjectsPanel } from "./subjects-panel";
import { ClassesPanel } from "./classes-panel";

export default async function ClassesPage() {
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

  const [{ data: classes }, { data: subjects }, { data: classSubjects }, { data: sections }] =
    await Promise.all([
      supabase
        .from("classes")
        .select("id, name, sort_order")
        .eq("school_id", schoolId)
        .order("sort_order")
        .order("name"),
      supabase
        .from("subjects")
        .select("id, name, code")
        .eq("school_id", schoolId)
        .order("name"),
      supabase.from("class_subjects").select("class_id, subject_id").eq("school_id", schoolId),
      activeYear
        ? supabase
            .from("sections")
            .select("id, class_id, name")
            .eq("school_id", schoolId)
            .eq("academic_year_id", activeYear.id)
            .order("name")
        : Promise.resolve({ data: [] as { id: string; class_id: string; name: string }[] }),
    ]);

  return (
    <div className="mx-auto max-w-5xl space-y-6 pb-8">
      <PageHeader
        title="Classes & subjects"
        description="Build your grade → section → subject structure."
      />

      {!activeYear && (
        <div className="flex items-start gap-4 rounded-2xl border border-amber-200/60 bg-amber-50/60 px-5 py-4">
          <span className="flex size-10 shrink-0 items-center justify-center rounded-xl bg-amber-100 text-amber-700 ring-1 ring-amber-200">
            <CalendarClock className="size-5" />
          </span>
          <div className="min-w-0 flex-1 pt-0.5">
            <p className="text-sm font-semibold text-amber-900">No active academic year</p>
            <p className="mt-0.5 text-xs text-amber-700/80">
              Set an active academic year in{" "}
            <a href="/settings/school" className="font-medium text-amber-800 underline">
                School profile
              </a>{" "}
              before adding sections.
            </p>
          </div>
        </div>
      )}

      <SubjectsPanel subjects={subjects ?? []} />

      <ClassesPanel
        classes={classes ?? []}
        subjects={subjects ?? []}
        classSubjects={classSubjects ?? []}
        sections={sections ?? []}
        canAddSections={Boolean(activeYear)}
      />
    </div>
  );
}
