import { redirect } from "next/navigation";
import { CalendarClock } from "lucide-react";
import { requireActiveMembership } from "@/lib/auth/session";
import { createClient } from "@/lib/supabase/server";
import { PageHeader } from "@/components/page-header";
import { Alert, AlertDescription } from "@/components/ui/alert";
import { SectionPicker } from "./section-picker";
import { TimetableGrid } from "./timetable-grid";
import { EventsCard } from "./events-card";

export type Option = { id: string; name: string };
export type SectionOption = { id: string; name: string; classId: string };
export type PeriodCell = {
  id: string;
  weekday: number;
  periodNo: number;
  subjectId: string | null;
  subjectName: string;
  staffName: string | null;
  startTime: string | null;
  endTime: string | null;
};

export default async function TimetablePage({
  searchParams,
}: {
  searchParams: Promise<{ section?: string }>;
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
        <PageHeader title="Timetable" description="Weekly schedule, holidays and events." />
        <Alert className="border-amber-200/60 bg-amber-50/60 text-amber-900">
          <CalendarClock className="size-4 text-amber-600" />
          <AlertDescription>Set an active academic year and create sections first.</AlertDescription>
        </Alert>
      </div>
    );
  }

  const [{ data: sections }, { data: subjects }, { data: classSubjects }, { data: staffRows }, { data: events }] =
    await Promise.all([
      supabase
        .from("sections")
        .select("id, name, class_id, classes(name)")
        .eq("school_id", schoolId)
        .eq("academic_year_id", activeYear.id)
        .order("name"),
      supabase.from("subjects").select("id, name").eq("school_id", schoolId),
      supabase.from("class_subjects").select("class_id, subject_id").eq("school_id", schoolId),
      supabase.from("staff").select("id, profiles(full_name, email)").eq("school_id", schoolId).eq("status", "active"),
      supabase
        .from("events")
        .select("id, title, description, start_date, end_date, is_holiday, section_id, sections(name, classes(name))")
        .eq("school_id", schoolId)
        .order("start_date", { ascending: false }),
    ]);

  const sectionOptions: SectionOption[] = (sections ?? []).map((s) => ({
    id: s.id,
    name: `${(s.classes as { name: string } | null)?.name ?? ""} · ${s.name}`,
    classId: s.class_id,
  }));
  const selectedId = sectionOptions.find((s) => s.id === sp.section)?.id ?? sectionOptions[0]?.id ?? "";
  const selected = sectionOptions.find((s) => s.id === selectedId);

  const subjectName = new Map((subjects ?? []).map((s) => [s.id, s.name]));
  const subjectsForClass: Option[] = selected
    ? (classSubjects ?? [])
        .filter((cs) => cs.class_id === selected.classId)
        .map((cs) => ({ id: cs.subject_id, name: subjectName.get(cs.subject_id) ?? "Subject" }))
    : [];
  const staff: Option[] = (staffRows ?? []).map((s) => {
    const p = s.profiles as { full_name: string | null; email: string | null } | null;
    return { id: s.id, name: p?.full_name || p?.email || "Staff" };
  });
  const staffName = new Map(staff.map((s) => [s.id, s.name]));

  let periods: PeriodCell[] = [];
  if (selectedId) {
    const { data } = await supabase
      .from("periods")
      .select("id, weekday, period_no, subject_id, staff_id, start_time, end_time")
      .eq("section_id", selectedId)
      .eq("academic_year_id", activeYear.id);
    periods = (data ?? []).map((p) => ({
      id: p.id,
      weekday: p.weekday,
      periodNo: p.period_no,
      subjectId: p.subject_id,
      subjectName: p.subject_id ? subjectName.get(p.subject_id) ?? "Subject" : "—",
      staffName: p.staff_id ? staffName.get(p.staff_id) ?? null : null,
      startTime: p.start_time,
      endTime: p.end_time,
    }));
  }

  const eventRows = (events ?? []).map((e) => {
    const sec = e.sections as { name: string; classes: { name: string } | null } | null;
    return {
      id: e.id,
      title: e.title,
      description: e.description,
      startDate: e.start_date,
      endDate: e.end_date,
      isHoliday: e.is_holiday,
      scope: e.section_id && sec ? `${sec.classes?.name ?? ""} · ${sec.name}` : "Whole school",
    };
  });

  return (
    <div className="mx-auto max-w-4xl space-y-6">
      <PageHeader
        title="Timetable"
        description={`Weekly schedule for ${activeYear.name}.`}
        action={<SectionPicker sections={sectionOptions} selected={selectedId} />}
      />

      {selectedId ? (
        <TimetableGrid
          sectionId={selectedId}
          periods={periods}
          subjects={subjectsForClass}
          staff={staff}
          canEdit={isAdmin}
        />
      ) : (
        <Alert>
          <CalendarClock className="size-4" />
          <AlertDescription>Create a section in Classes &amp; subjects to build a timetable.</AlertDescription>
        </Alert>
      )}

      {/* only staff reach this page; events are admin/teacher-writable */}
      <EventsCard events={eventRows} sections={sectionOptions} canEdit />

    </div>
  );
}
