import { redirect } from "next/navigation";
import { requireActiveMembership } from "@/lib/auth/session";
import { createClient } from "@/lib/supabase/server";
import { PageHeader } from "@/components/page-header";
import { SchoolProfileForm } from "./school-profile-form";
import { AcademicYears } from "./academic-years";

export default async function SchoolProfilePage() {
  const membership = await requireActiveMembership();
  if (membership.role !== "school_admin") redirect("/dashboard");

  const supabase = await createClient();
  const [{ data: school }, { data: years }] = await Promise.all([
    supabase.from("schools").select("*").eq("id", membership.schoolId).single(),
    supabase
      .from("academic_years")
      .select("*")
      .eq("school_id", membership.schoolId)
      .order("start_date", { ascending: false }),
  ]);

  if (!school) redirect("/dashboard");

  return (
    <div className="mx-auto max-w-3xl space-y-6">
      <PageHeader
        title="School profile"
        description="Your school's identity and academic calendar."
      />
      <SchoolProfileForm school={school} />
      <AcademicYears years={years ?? []} />
    </div>
  );
}
