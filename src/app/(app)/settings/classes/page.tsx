import { redirect } from "next/navigation";
import { requireActiveMembership } from "@/lib/auth/session";
import { createClient } from "@/lib/supabase/server";
import { PageHeader } from "@/components/page-header";
import { Alert, AlertDescription } from "@/components/ui/alert";
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
    <div className="mx-auto max-w-4xl space-y-6">
      <PageHeader
        title="Classes & subjects"
        description="Build your grade → section → subject structure."
      />

      {!activeYear && (
        <Alert>
          <CalendarClock className="size-4" />
          <AlertDescription>
            Set an active academic year in{" "}
            <a href="/settings/school" className="font-medium text-accent underline">
              School profile
            </a>{" "}
            before adding sections.
          </AlertDescription>
        </Alert>
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
