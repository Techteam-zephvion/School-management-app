import type { ComponentType, ReactNode } from "react";
import Link from "next/link";
import {
  AlertTriangle,
  ArrowRight,
  ArrowUpRight,
  BookOpen,
  CalendarClock,
  CheckCircle2,
  Circle,
  ClipboardCheck,
  Clock,
  FileSpreadsheet,
  GraduationCap,
  Megaphone,
  Sparkles,
  Star,
  UserPlus,
  Users,
  Wallet,
} from "lucide-react";
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { getProfile, requireActiveMembership } from "@/lib/auth/session";
import { createClient } from "@/lib/supabase/server";
import { cn, formatMoney } from "@/lib/utils";
import { PendingLeave, type LeaveItem } from "./pending-leave";

type IconComponent = ComponentType<{ className?: string }>;
type Tone = "blue" | "cyan" | "emerald" | "amber" | "slate";

type AnnouncementRow = {
  id: string;
  title: string;
  audience: string;
  created_at: string;
};

type HomeworkRow = {
  id: string;
  title: string;
  due_date: string;
  subjects: unknown;
  sections: unknown;
};

type QuickAction = {
  href: string;
  label: string;
  description: string;
  icon: IconComponent;
  tone: Tone;
};

const toneStyles: Record<
  Tone,
  {
    icon: string;
    panel: string;
    border: string;
    progress: string;
    text: string;
  }
> = {
  blue: {
    icon: "bg-blue-50 text-blue-700 ring-blue-100",
    panel: "from-blue-50 to-white",
    border: "border-blue-100",
    progress: "bg-blue-600",
    text: "text-blue-700",
  },
  cyan: {
    icon: "bg-cyan-50 text-cyan-700 ring-cyan-100",
    panel: "from-cyan-50 to-white",
    border: "border-cyan-100",
    progress: "bg-cyan-600",
    text: "text-cyan-700",
  },
  emerald: {
    icon: "bg-emerald-50 text-emerald-700 ring-emerald-100",
    panel: "from-emerald-50 to-white",
    border: "border-emerald-100",
    progress: "bg-emerald-600",
    text: "text-emerald-700",
  },
  amber: {
    icon: "bg-amber-50 text-amber-700 ring-amber-100",
    panel: "from-amber-50 to-white",
    border: "border-amber-100",
    progress: "bg-amber-500",
    text: "text-amber-700",
  },
  slate: {
    icon: "bg-slate-100 text-slate-700 ring-slate-200",
    panel: "from-slate-50 to-white",
    border: "border-slate-200",
    progress: "bg-slate-700",
    text: "text-slate-700",
  },
};

function greeting() {
  const h = new Date().getHours();
  return h < 12 ? "Good morning" : h < 17 ? "Good afternoon" : "Good evening";
}

function fmtTime(t: string | null) {
  if (!t) return "";
  const [h, m] = t.split(":");
  return `${h.padStart(2, "0")}:${m}`;
}

function nowMinutes() {
  const d = new Date();
  return d.getHours() * 60 + d.getMinutes();
}

function toMin(t: string) {
  const [h, m] = t.split(":");
  return Number(h) * 60 + Number(m);
}

function dueLabel(dateStr: string) {
  const d = new Date(`${dateStr}T00:00:00`);
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const days = Math.round((d.getTime() - today.getTime()) / 86400000);
  if (days < 0) return { text: "Overdue", tone: "destructive" as const };
  if (days === 0) return { text: "Due today", tone: "warning" as const };
  if (days === 1) return { text: "Due tomorrow", tone: "secondary" as const };
  return { text: `Due in ${days} days`, tone: "secondary" as const };
}

function fullName(first: string, last: string | null) {
  return [first, last].filter(Boolean).join(" ");
}

function leaveDetail(from: string, to: string, reason: string | null) {
  const days =
    Math.round((new Date(to).getTime() - new Date(from).getTime()) / 86400000) +
    1;
  return `${reason?.trim() || "Leave"} · ${days} day${days > 1 ? "s" : ""}`;
}

function clampPercent(value: number) {
  return Math.min(100, Math.max(0, value));
}

export default async function DashboardPage() {
  const membership = await requireActiveMembership();
  const profile = await getProfile();
  const supabase = await createClient();

  const [{ data: school }, { data: academicYear }] = await Promise.all([
    supabase.from("schools").select("*").eq("id", membership.schoolId).single(),
    supabase
      .from("academic_years")
      .select("*")
      .eq("school_id", membership.schoolId)
      .eq("is_active", true)
      .maybeSingle(),
  ]);

  const firstName = profile?.full_name?.split(" ")[0] || "there";
  const todayISO = new Date().toLocaleDateString("en-CA");
  const weekday = (new Date().getDay() + 6) % 7;

  if (membership.role === "teacher") {
    const { data: staff } = await supabase
      .from("staff")
      .select("id")
      .eq("school_id", membership.schoolId)
      .eq("user_id", profile?.id ?? "")
      .maybeSingle();
    const staffId = staff?.id ?? "";

    const [
      { data: ctSections },
      { data: assignments },
      { data: periods },
      { data: announcements },
    ] = await Promise.all([
      supabase
        .from("sections")
        .select("id, name, classes(name)")
        .eq("class_teacher_staff_id", staffId),
      supabase
        .from("teacher_assignments")
        .select("section_id")
        .eq("staff_id", staffId),
      supabase
        .from("periods")
        .select("start_time, end_time, subjects(name), sections(name, classes(name))")
        .eq("staff_id", staffId)
        .eq("weekday", weekday)
        .order("start_time"),
      supabase
        .from("announcements")
        .select("id, title, audience, created_at")
        .order("created_at", { ascending: false })
        .limit(3),
    ]);

    const ctSectionIds = (ctSections ?? []).map((s) => s.id);
    const allSectionIds = [
      ...new Set([
        ...ctSectionIds,
        ...(assignments ?? []).map((a) => a.section_id),
      ]),
    ];

    const [{ count: studentCount }, { data: homework }, { data: attToday }, { data: myEnrol }] =
      await Promise.all([
        allSectionIds.length
          ? supabase
              .from("enrollments")
              .select("student_id", { count: "exact", head: true })
              .in("section_id", allSectionIds)
              .eq("status", "active")
          : Promise.resolve({ count: 0 }),
        allSectionIds.length
          ? supabase
              .from("homework")
              .select("id, title, due_date, subjects(name), sections(name, classes(name))")
              .in("section_id", allSectionIds)
              .gte("due_date", todayISO)
              .order("due_date")
              .limit(4)
          : Promise.resolve({ data: [] }),
        ctSectionIds.length
          ? supabase
              .from("attendance")
              .select("section_id")
              .in("section_id", ctSectionIds)
              .eq("date", todayISO)
              .is("subject_id", null)
          : Promise.resolve({ data: [] }),
        ctSectionIds.length
          ? supabase
              .from("enrollments")
              .select("student_id")
              .in("section_id", ctSectionIds)
              .eq("status", "active")
          : Promise.resolve({ data: [] }),
      ]);

    const markedSections = new Set((attToday ?? []).map((a) => a.section_id));
    const pendingAttendance = ctSectionIds.filter((id) => !markedSections.has(id)).length;
    const completionRate =
      ctSectionIds.length > 0
        ? Math.round(((ctSectionIds.length - pendingAttendance) / ctSectionIds.length) * 100)
        : 100;

    const myStudentIds = (myEnrol ?? []).map((e) => e.student_id);
    let leaveItems: LeaveItem[] = [];
    if (myStudentIds.length) {
      const { data: leaves } = await supabase
        .from("leave_requests")
        .select("id, from_date, to_date, reason, students(first_name, last_name)")
        .in("student_id", myStudentIds)
        .eq("status", "pending")
        .order("created_at", { ascending: false })
        .limit(5);
      leaveItems = (leaves ?? []).map((l) => {
        const s = l.students as { first_name: string; last_name: string | null } | null;
        return {
          id: l.id,
          studentName: s ? fullName(s.first_name, s.last_name) : "Student",
          detail: leaveDetail(l.from_date, l.to_date, l.reason),
        };
      });
    }

    const now = nowMinutes();
    const classes = (periods ?? []).map((p) => {
      const sec = p.sections as { name: string; classes: { name: string } | null } | null;
      const start = p.start_time ? toMin(p.start_time) : null;
      const end = p.end_time ? toMin(p.end_time) : null;
      const status =
        start != null && end != null
          ? now >= start && now <= end
            ? "Live"
            : now > end
              ? "Done"
              : "Upcoming"
          : "Upcoming";
      return {
        time: fmtTime(p.start_time),
        subject: (p.subjects as { name: string } | null)?.name ?? "Class",
        where: sec ? `${sec.classes?.name ?? ""} · ${sec.name}` : "",
        status,
      };
    });

    return (
      <DashboardShell>
        <DashboardHero
          greetingText={greeting()}
          firstName={firstName}
        />

        <QuickActions role="teacher" />

        <div className="grid gap-5 xl:grid-cols-[minmax(0,1.55fr)_minmax(320px,0.8fr)]">
          <SectionCard
            className="min-h-[360px]"
            icon={Clock}
            title="Today's classes"
            eyebrow="Live timetable"
            action={{ label: "Full timetable", href: "/timetable" }}
          >
            {classes.length === 0 ? (
              <Empty icon={CalendarClock} text="No classes scheduled for today." />
            ) : (
              <ClassTimeline classes={classes} />
            )}
          </SectionCard>

          <div className="grid gap-5 sm:grid-cols-2 xl:grid-cols-1">
            <MetricCard
              label="My students"
              value={String(studentCount ?? 0)}
              sub={`${allSectionIds.length} assigned section${allSectionIds.length === 1 ? "" : "s"}`}
              icon={Users}
              tone="blue"
            />
            <AttendancePendingCard count={pendingAttendance} completionRate={completionRate} />
          </div>
        </div>

        <div className="grid gap-5 xl:grid-cols-2">
          <SectionCard
            icon={BookOpen}
            title="Homework due"
            eyebrow="Student workload"
            action={{ label: "All homework", href: "/homework" }}
          >
            {(homework ?? []).length === 0 ? (
              <Empty icon={BookOpen} text="Nothing due right now." />
            ) : (
              <HomeworkList rows={(homework ?? []) as HomeworkRow[]} />
            )}
          </SectionCard>

          <AnnouncementsCard rows={announcements ?? []} />
        </div>

        <SectionCard
          icon={CalendarClock}
          title="Leave requests to review"
          eyebrow="Class teacher queue"
          action={{ label: "Open leave", href: "/leave" }}
        >
          <PendingLeave items={leaveItems} canReview={ctSectionIds.length > 0} />
        </SectionCard>
      </DashboardShell>
    );
  }

  const [
    { count: studentCount },
    { count: teacherCount },
    { count: classCount },
    { data: sections },
    { data: attToday },
    { data: invoices },
    { data: announcements },
    { data: leaves },
    { data: examTerms },
  ] = await Promise.all([
    supabase
      .from("students")
      .select("id", { count: "exact", head: true })
      .eq("school_id", membership.schoolId),
    supabase
      .from("school_members")
      .select("id", { count: "exact", head: true })
      .eq("school_id", membership.schoolId)
      .eq("role", "teacher")
      .eq("status", "active"),
    supabase
      .from("classes")
      .select("id", { count: "exact", head: true })
      .eq("school_id", membership.schoolId),
    academicYear
      ? supabase
          .from("sections")
          .select("id")
          .eq("school_id", membership.schoolId)
          .eq("academic_year_id", academicYear.id)
      : Promise.resolve({ data: [] }),
    supabase
      .from("attendance")
      .select("section_id")
      .eq("school_id", membership.schoolId)
      .eq("date", todayISO)
      .is("subject_id", null),
    supabase
      .from("invoices")
      .select("amount_total, amount_paid, status")
      .eq("school_id", membership.schoolId),
    supabase
      .from("announcements")
      .select("id, title, audience, created_at")
      .order("created_at", { ascending: false })
      .limit(3),
    supabase
      .from("leave_requests")
      .select("id, from_date, to_date, reason, students(first_name, last_name)")
      .eq("school_id", membership.schoolId)
      .eq("status", "pending")
      .order("created_at", { ascending: false })
      .limit(5),
    academicYear
      ? supabase
          .from("exam_terms")
          .select("id, name, is_published")
          .eq("school_id", membership.schoolId)
          .eq("academic_year_id", academicYear.id)
          .order("created_at", { ascending: false })
          .limit(3)
      : Promise.resolve({ data: [] }),
  ]);

  const totalSections = (sections ?? []).length;
  const markedSections = new Set((attToday ?? []).map((a) => a.section_id)).size;
  const collected = (invoices ?? []).reduce((s, i) => s + Number(i.amount_paid), 0);
  const billed = (invoices ?? []).reduce((s, i) => s + Number(i.amount_total), 0);
  const outstanding = Math.max(0, billed - collected);
  const overdue = (invoices ?? []).filter((i) => i.status === "overdue").length;
  const collectRate = billed > 0 ? Math.round((collected / billed) * 100) : 0;
  const attendanceRate =
    totalSections > 0 ? Math.round((markedSections / totalSections) * 100) : 0;

  const leaveItems: LeaveItem[] = (leaves ?? []).map((l) => {
    const s = l.students as { first_name: string; last_name: string | null } | null;
    return {
      id: l.id,
      studentName: s ? fullName(s.first_name, s.last_name) : "Student",
      detail: leaveDetail(l.from_date, l.to_date, l.reason),
    };
  });

  const setupSteps = [
    {
      label: "School profile",
      done: Boolean(school?.name && school?.address),
      href: "/settings/school",
    },
    {
      label: "Active academic year",
      done: Boolean(academicYear),
      href: "/settings/school",
    },
    {
      label: "Classes, sections & subjects",
      done: (classCount ?? 0) > 0,
      href: "/settings/classes",
    },
    {
      label: "Invite staff",
      done: (teacherCount ?? 0) > 0,
      href: "/settings/staff",
    },
    {
      label: "Add students & guardians",
      done: (studentCount ?? 0) > 0,
      href: "/students",
    },
  ];
  const completedSteps = setupSteps.filter((s) => s.done).length;
  const remaining = setupSteps.length - completedSteps;

  return (
    <DashboardShell>
      <DashboardHero
        greetingText={greeting()}
        firstName={firstName}
      />

      {remaining > 0 && (
        <SetupProgressCard steps={setupSteps} completed={completedSteps} total={setupSteps.length} />
      )}

      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <MetricCard
          label="Students"
          value={String(studentCount ?? 0)}
          sub="Active school records"
          icon={GraduationCap}
          tone="blue"
        />
        <MetricCard
          label="Teachers"
          value={String(teacherCount ?? 0)}
          sub="Active staff accounts"
          icon={Users}
          tone="cyan"
        />
        <MetricCard
          label="Attendance today"
          value={totalSections ? `${markedSections}/${totalSections}` : "-"}
          sub={totalSections ? `${totalSections - markedSections} sections pending` : "No sections yet"}
          icon={ClipboardCheck}
          tone={totalSections - markedSections > 0 ? "amber" : "emerald"}
          progress={attendanceRate}
        />
        <MetricCard
          label="Fees collected"
          value={formatMoney(collected)}
          sub={`${collectRate}% of ${formatMoney(billed)}`}
          icon={Wallet}
          tone="emerald"
          progress={collectRate}
        />
      </div>

      <QuickActions role="admin" />

      <div className="grid gap-5 xl:grid-cols-[minmax(0,1fr)_minmax(0,1fr)]">
        <FeeCollectionCard
          collected={collected}
          outstanding={outstanding}
          overdue={overdue}
          collectRate={collectRate}
        />
        <ExamsCard rows={examTerms ?? []} />
      </div>

      <div className="grid gap-5 xl:grid-cols-[minmax(0,1.1fr)_minmax(320px,0.9fr)]">
        <AnnouncementsCard rows={announcements ?? []} canPost />
        <SectionCard
          icon={CalendarClock}
          title="Leave requests pending"
          eyebrow="Approval queue"
          action={{ label: "Open leave", href: "/leave" }}
        >
          <PendingLeave items={leaveItems} canReview />
        </SectionCard>
      </div>
    </DashboardShell>
  );
}

function DashboardShell({ children }: { children: ReactNode }) {
  return <div className="mx-auto max-w-7xl space-y-6 pb-8">{children}</div>;
}

function DashboardHero({
  greetingText,
  firstName,
}: {
  greetingText: string;
  firstName: string;
}) {
  return (
    <section className="relative overflow-hidden rounded-2xl border border-blue-100/80 bg-[linear-gradient(135deg,#ffffff_0%,#f8fbff_58%,#eef7ff_100%)] px-5 py-6 shadow-sm shadow-slate-950/5 sm:px-7 sm:py-7">
      <div className="absolute inset-x-0 top-0 h-px bg-gradient-to-r from-transparent via-blue-300/60 to-transparent" />
      <div className="relative flex items-center gap-4">
        <span className="hidden h-10 w-1 rounded-full bg-blue-500/70 sm:block" />
        <h1 className="max-w-4xl text-2xl font-semibold tracking-normal text-slate-950 sm:text-3xl">
          {greetingText}, {firstName}
        </h1>
      </div>
    </section>
  );
}

function SectionCard({
  icon: Icon,
  title,
  eyebrow,
  action,
  className,
  children,
}: {
  icon: IconComponent;
  title: string;
  eyebrow?: string;
  action?: { label: string; href: string };
  className?: string;
  children: ReactNode;
}) {
  return (
    <Card
      className={cn(
        "overflow-hidden border border-slate-200/80 bg-white/95 shadow-sm shadow-slate-950/5 ring-1 ring-slate-900/[0.02] transition-shadow hover:shadow-md hover:shadow-slate-950/10",
        className
      )}
    >
      <CardHeader className="flex flex-row items-start justify-between gap-3 space-y-0 pb-4">
        <div className="flex min-w-0 items-start gap-3">
          <span className="flex size-10 shrink-0 items-center justify-center rounded-2xl bg-blue-50 text-blue-700 ring-1 ring-blue-100">
            <Icon className="size-5" />
          </span>
          <div className="min-w-0">
            {eyebrow && (
              <p className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">
                {eyebrow}
              </p>
            )}
            <CardTitle className="mt-0.5 truncate text-base text-slate-950">
              {title}
            </CardTitle>
          </div>
        </div>
        {action && (
          <Link
            href={action.href}
            className="inline-flex shrink-0 items-center gap-1 rounded-lg px-2 py-1 text-xs font-semibold text-blue-700 transition-colors hover:bg-blue-50 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
          >
            {action.label}
            <ArrowRight className="size-3.5" />
          </Link>
        )}
      </CardHeader>
      <CardContent className="pt-0">{children}</CardContent>
    </Card>
  );
}

function MetricCard({
  label,
  value,
  sub,
  icon: Icon,
  tone,
  progress,
}: {
  label: string;
  value: string;
  sub?: string;
  icon: IconComponent;
  tone: Tone;
  progress?: number;
}) {
  const styles = toneStyles[tone];
  const pct = progress == null ? null : clampPercent(progress);

  return (
    <div
      className={cn(
        "rounded-2xl border bg-gradient-to-br p-4 shadow-sm shadow-slate-950/5 transition-all motion-safe:hover:-translate-y-0.5 hover:shadow-md",
        styles.panel,
        styles.border
      )}
    >
      <div className="flex items-start justify-between gap-3">
        <div className="min-w-0">
          <p className="text-xs font-semibold uppercase tracking-wide text-slate-500">
            {label}
          </p>
          <p className="mt-1 truncate text-2xl font-bold text-slate-950">{value}</p>
          {sub && <p className="mt-1 truncate text-xs text-slate-500">{sub}</p>}
        </div>
        <span className={cn("flex size-11 shrink-0 items-center justify-center rounded-2xl ring-1", styles.icon)}>
          <Icon className="size-5" />
        </span>
      </div>
      {pct != null && (
        <div className="mt-4 h-2 overflow-hidden rounded-full bg-slate-200/70">
          <div
            className={cn("h-full rounded-full", styles.progress)}
            style={{ width: `${pct}%` }}
          />
        </div>
      )}
    </div>
  );
}

function AttendancePendingCard({
  count,
  completionRate,
}: {
  count: number;
  completionRate: number;
}) {
  const done = count === 0;
  return (
    <div
      className={cn(
        "rounded-2xl border p-4 shadow-sm shadow-slate-950/5",
        done
          ? "border-emerald-100 bg-gradient-to-br from-emerald-50 to-white"
          : "border-amber-100 bg-gradient-to-br from-amber-50 to-white"
      )}
    >
      <div className="flex items-start justify-between gap-3">
        <div>
          <p className="text-xs font-semibold uppercase tracking-wide text-slate-500">
            Attendance pending
          </p>
          <p className="mt-1 text-2xl font-bold text-slate-950">
            {done ? "All done" : `${count} class${count > 1 ? "es" : ""}`}
          </p>
          <p className="mt-1 text-xs text-slate-500">
            {done ? "Today's registers are complete." : "Resolve before the day closes."}
          </p>
        </div>
        <span
          className={cn(
            "flex size-11 shrink-0 items-center justify-center rounded-2xl ring-1",
            done
              ? "bg-emerald-50 text-emerald-700 ring-emerald-100"
              : "bg-amber-50 text-amber-700 ring-amber-100"
          )}
        >
          <ClipboardCheck className="size-5" />
        </span>
      </div>
      <div className="mt-4 h-2 overflow-hidden rounded-full bg-slate-200/70">
        <div
          className={cn("h-full rounded-full", done ? "bg-emerald-600" : "bg-amber-500")}
          style={{ width: `${clampPercent(completionRate)}%` }}
        />
      </div>
      {!done && (
        <Button asChild size="sm" className="mt-4 h-9 w-full bg-amber-500 text-white hover:bg-amber-600">
          <Link href="/attendance">Resolve pending</Link>
        </Button>
      )}
    </div>
  );
}

function ClassTimeline({
  classes,
}: {
  classes: { time: string; subject: string; where: string; status: string }[];
}) {
  return (
    <div className="space-y-3">
      {classes.map((c, i) => (
        <div
          key={`${c.time}-${c.subject}-${i}`}
          className={cn(
            "grid grid-cols-[64px_1fr_auto] items-center gap-4 rounded-2xl border px-4 py-3",
            c.status === "Live"
              ? "border-blue-100 bg-blue-50/80"
              : "border-slate-200/80 bg-slate-50/60"
          )}
        >
          <div className="text-sm font-bold tabular-nums text-slate-700">{c.time}</div>
          <div className="min-w-0 border-l-4 border-blue-500 pl-4">
            <p className="truncate text-sm font-bold text-slate-950">{c.subject}</p>
            <p className="mt-0.5 truncate text-xs text-slate-500">{c.where}</p>
          </div>
          <Badge
            variant={
              c.status === "Live" ? "default" : c.status === "Done" ? "outline" : "secondary"
            }
          >
            {c.status}
          </Badge>
        </div>
      ))}
    </div>
  );
}

function HomeworkList({ rows }: { rows: HomeworkRow[] }) {
  return (
    <div className="space-y-3">
      {rows.map((h) => {
        const due = dueLabel(h.due_date);
        const subject = h.subjects as { name: string } | null;
        const section = h.sections as { name: string; classes: { name: string } | null } | null;
        return (
          <div
            key={h.id}
            className="flex items-center gap-3 rounded-2xl border border-slate-200/80 bg-slate-50/60 px-3 py-3"
          >
            <span className="flex size-10 shrink-0 items-center justify-center rounded-2xl bg-blue-50 text-blue-700 ring-1 ring-blue-100">
              <BookOpen className="size-5" />
            </span>
            <div className="min-w-0 flex-1">
              <p className="truncate text-sm font-semibold text-slate-950">{h.title}</p>
              <p className="mt-0.5 truncate text-xs text-slate-500">
                {subject?.name ?? "Subject"} ·{" "}
                {section
                  ? `${section.classes?.name ?? "Class"} · ${section.name}`
                  : "Section"}
              </p>
            </div>
            <Badge variant={due.tone}>{due.text}</Badge>
          </div>
        );
      })}
    </div>
  );
}

function AnnouncementsCard({
  rows,
  canPost,
}: {
  rows: AnnouncementRow[];
  canPost?: boolean;
}) {
  return (
    <SectionCard
      icon={Megaphone}
      title="Recent announcements"
      eyebrow="School communication"
      action={{ label: canPost ? "New post" : "View all", href: "/notices" }}
    >
      {rows.length === 0 ? (
        <Empty icon={Megaphone} text="No announcements yet." />
      ) : (
        <div className="space-y-3">
          {rows.map((a) => (
            <Link
              key={a.id}
              href={`/notices/${a.id}`}
              className="group block rounded-2xl border border-slate-200/80 bg-slate-50/60 px-4 py-3 transition-colors hover:border-blue-200 hover:bg-blue-50/60 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
            >
              <div className="flex items-center justify-between gap-3">
                <p className="truncate text-sm font-semibold text-slate-950">{a.title}</p>
                <Badge variant="outline" className="shrink-0 capitalize">
                  {a.audience}
                </Badge>
              </div>
              <p className="mt-1 text-xs text-slate-500">
                {new Date(a.created_at).toLocaleDateString("en-IN", {
                  day: "numeric",
                  month: "short",
                })}
              </p>
            </Link>
          ))}
        </div>
      )}
    </SectionCard>
  );
}

function SetupProgressCard({
  steps,
  completed,
  total,
}: {
  steps: { label: string; done: boolean; href: string }[];
  completed: number;
  total: number;
}) {
  const progress = total > 0 ? Math.round((completed / total) * 100) : 0;

  return (
    <section className="rounded-3xl border border-blue-100 bg-gradient-to-br from-blue-50 via-white to-cyan-50 p-4 shadow-sm shadow-blue-950/5 sm:p-5">
      <div className="grid gap-5 lg:grid-cols-[280px_1fr] lg:items-center">
        <div>
          <div className="flex items-center gap-2 text-blue-700">
            <Sparkles className="size-4.5" />
            <p className="text-xs font-bold uppercase tracking-wide">Setup progress</p>
          </div>
          <h2 className="mt-2 text-lg font-bold text-slate-950">Finish your school workspace</h2>
          <p className="mt-1 text-sm text-slate-500">
            {completed} of {total} foundation steps are complete.
          </p>
          <div className="mt-4 h-2 overflow-hidden rounded-full bg-blue-100">
            <div className="h-full rounded-full bg-blue-600" style={{ width: `${progress}%` }} />
          </div>
        </div>
        <div className="grid gap-2 sm:grid-cols-2 xl:grid-cols-5">
          {steps.map((step) => (
            <Link
              key={step.label}
              href={step.href}
              className={cn(
                "flex min-h-[82px] items-start gap-3 rounded-2xl border bg-white/80 p-3 transition-colors hover:border-blue-200 hover:bg-white focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring",
                step.done ? "border-emerald-100" : "border-slate-200"
              )}
            >
              {step.done ? (
                <CheckCircle2 className="mt-0.5 size-4.5 shrink-0 text-emerald-600" />
              ) : (
                <Circle className="mt-0.5 size-4.5 shrink-0 text-slate-400" />
              )}
              <span
                className={cn(
                  "text-sm font-semibold leading-5",
                  step.done ? "text-slate-500" : "text-slate-900"
                )}
              >
                {step.label}
              </span>
            </Link>
          ))}
        </div>
      </div>
    </section>
  );
}

function FeeCollectionCard({
  collected,
  outstanding,
  overdue,
  collectRate,
}: {
  collected: number;
  outstanding: number;
  overdue: number;
  collectRate: number;
}) {
  return (
    <SectionCard
      icon={Wallet}
      title="Fee collection"
      eyebrow="Finance snapshot"
      action={{ label: "Open fees", href: "/settings/fees" }}
    >
      <div className="space-y-5">
        <div className="grid gap-3 sm:grid-cols-2">
          <div className="rounded-2xl border border-emerald-100 bg-emerald-50/80 p-4">
            <p className="text-xs font-semibold uppercase tracking-wide text-emerald-700">
              Collected
            </p>
            <p className="mt-1 text-2xl font-bold text-slate-950">{formatMoney(collected)}</p>
          </div>
          <div className="rounded-2xl border border-slate-200 bg-slate-50/80 p-4">
            <p className="text-xs font-semibold uppercase tracking-wide text-slate-500">
              Outstanding
            </p>
            <p className="mt-1 text-2xl font-bold text-slate-950">{formatMoney(outstanding)}</p>
          </div>
        </div>
        <div>
          <div className="mb-2 flex items-center justify-between text-xs">
            <span className="font-semibold text-slate-500">{collectRate}% collected</span>
            {overdue > 0 && (
              <span className="flex items-center gap-1 font-semibold text-destructive">
                <AlertTriangle className="size-3.5" />
                {overdue} overdue
              </span>
            )}
          </div>
          <div className="h-2.5 overflow-hidden rounded-full bg-slate-200">
            <div
              className="h-full rounded-full bg-gradient-to-r from-emerald-500 to-blue-600"
              style={{ width: `${clampPercent(collectRate)}%` }}
            />
          </div>
        </div>
      </div>
    </SectionCard>
  );
}

function ExamsCard({
  rows,
}: {
  rows: { id: string; name: string; is_published: boolean }[];
}) {
  return (
    <SectionCard
      icon={FileSpreadsheet}
      title="Exams"
      eyebrow="Marks pipeline"
      action={{ label: "Marks & exams", href: "/exams" }}
    >
      {rows.length === 0 ? (
        <Empty icon={FileSpreadsheet} text="No exam terms yet." />
      ) : (
        <div className="space-y-3">
          {rows.map((t) => (
            <div
              key={t.id}
              className="flex items-center justify-between gap-3 rounded-2xl border border-slate-200/80 bg-slate-50/60 px-4 py-3"
            >
              <div className="min-w-0">
                <p className="truncate text-sm font-semibold text-slate-950">{t.name}</p>
                <p className="mt-0.5 text-xs text-slate-500">
                  {t.is_published ? "Visible to parents" : "Draft marks setup"}
                </p>
              </div>
              <Badge variant={t.is_published ? "success" : "secondary"}>
                {t.is_published ? "Published" : "Draft"}
              </Badge>
            </div>
          ))}
        </div>
      )}
    </SectionCard>
  );
}

function Empty({ icon: Icon, text }: { icon: IconComponent; text: string }) {
  return (
    <div className="flex min-h-[170px] flex-col items-center justify-center gap-3 rounded-2xl border border-dashed border-slate-200 bg-slate-50/70 px-4 py-8 text-center">
      <span className="flex size-12 items-center justify-center rounded-2xl bg-white text-slate-500 ring-1 ring-slate-200">
        <Icon className="size-5" />
      </span>
      <p className="max-w-xs text-sm text-slate-500">{text}</p>
    </div>
  );
}

function QuickActions({ role }: { role: "admin" | "teacher" }) {
  const actions: QuickAction[] =
    role === "admin"
      ? [
          {
            href: "/attendance",
            label: "Mark attendance",
            description: "Close today's register",
            icon: ClipboardCheck,
            tone: "blue",
          },
          {
            href: "/students",
            label: "Add student",
            description: "Create profile and enrollment",
            icon: UserPlus,
            tone: "cyan",
          },
          {
            href: "/notices",
            label: "Announcement",
            description: "Notify classes or guardians",
            icon: Megaphone,
            tone: "amber",
          },
          {
            href: "/settings/fees",
            label: "Fees",
            description: "Review invoices and payments",
            icon: Wallet,
            tone: "emerald",
          },
        ]
      : [
          {
            href: "/attendance",
            label: "Mark attendance",
            description: "Quick class registry",
            icon: ClipboardCheck,
            tone: "blue",
          },
          {
            href: "/exams",
            label: "Add marks",
            description: "Upload exam results",
            icon: Star,
            tone: "cyan",
          },
          {
            href: "/homework",
            label: "Set homework",
            description: "Assign class practice",
            icon: BookOpen,
            tone: "emerald",
          },
          {
            href: "/notices",
            label: "Announcement",
            description: "Share a class update",
            icon: Megaphone,
            tone: "amber",
          },
        ];

  return (
    <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
      {actions.map((a) => {
        const Icon = a.icon;
        const styles = toneStyles[a.tone];
        return (
          <Link
            key={a.href}
            href={a.href}
            className={cn(
              "group flex min-h-[92px] items-center gap-4 rounded-2xl border bg-white p-4 shadow-sm shadow-slate-950/5 transition-all motion-safe:hover:-translate-y-0.5 hover:border-blue-200 hover:shadow-md focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring",
              styles.border
            )}
          >
            <span className={cn("flex size-12 shrink-0 items-center justify-center rounded-2xl ring-1", styles.icon)}>
              <Icon className="size-5" />
            </span>
            <span className="min-w-0 flex-1">
              <span className="block truncate text-sm font-bold text-slate-950">{a.label}</span>
              <span className="mt-0.5 block truncate text-xs text-slate-500">{a.description}</span>
            </span>
            <ArrowUpRight className={cn("size-4 shrink-0 opacity-0 transition-opacity group-hover:opacity-100", styles.text)} />
          </Link>
        );
      })}
    </div>
  );
}
