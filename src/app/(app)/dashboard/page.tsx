import Link from "next/link";
import { CheckCircle2, Circle, ClipboardCheck, Megaphone, Star, Users } from "lucide-react";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { getProfile, requireActiveMembership } from "@/lib/auth/session";
import { createClient } from "@/lib/supabase/server";

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
  const today = new Date().toLocaleDateString("en-IN", {
    weekday: "long",
    month: "long",
    day: "numeric",
  });

  if (membership.role === "teacher") {
    // This teacher's own staff record -> their subject assignments + class-teacher sections.
    const { data: staff } = await supabase
      .from("staff")
      .select("id")
      .eq("school_id", membership.schoolId)
      .eq("user_id", profile?.id ?? "")
      .maybeSingle();

    let assignments: { id: string; label: string; subject: string }[] = [];
    let classTeacherOf: string[] = [];
    if (staff) {
      const [{ data: ta }, { data: ct }] = await Promise.all([
        supabase
          .from("teacher_assignments")
          .select("id, sections(name, classes(name)), subjects(name)")
          .eq("staff_id", staff.id),
        supabase
          .from("sections")
          .select("name, classes(name)")
          .eq("class_teacher_staff_id", staff.id),
      ]);
      assignments = (ta ?? []).map((a) => {
        const section = a.sections as { name: string; classes: { name: string } | null } | null;
        return {
          id: a.id,
          label: `${section?.classes?.name ?? ""} · ${section?.name ?? ""}`,
          subject: (a.subjects as { name: string } | null)?.name ?? "",
        };
      });
      classTeacherOf = (ct ?? []).map((s) => {
        const section = s as { name: string; classes: { name: string } | null };
        return `${section.classes?.name ?? ""} · ${section.name}`;
      });
    }

    return (
      <div className="space-y-6">
        <div>
          <h1 className="text-2xl font-bold tracking-tight">
            Good morning, {firstName}
          </h1>
          <p className="text-muted-foreground">
            {school?.name ?? "Your school"} · {today}
          </p>
        </div>
        <QuickActions />
        <Card>
          <CardHeader>
            <CardTitle>Your classes</CardTitle>
            <CardDescription>
              {assignments.length === 0 && classTeacherOf.length === 0
                ? "No assignments yet — your admin will map your sections and subjects."
                : "Sections and subjects assigned to you this year."}
            </CardDescription>
          </CardHeader>
          {(assignments.length > 0 || classTeacherOf.length > 0) && (
            <CardContent className="space-y-4">
              {classTeacherOf.length > 0 && (
                <div>
                  <p className="mb-1.5 text-xs font-medium tracking-wide text-muted-foreground uppercase">
                    Class teacher of
                  </p>
                  <div className="flex flex-wrap gap-2">
                    {classTeacherOf.map((label) => (
                      <span
                        key={label}
                        className="inline-flex items-center gap-1.5 rounded-full bg-accent/10 px-3 py-1 text-sm font-medium text-accent"
                      >
                        <Star className="size-3.5" /> {label}
                      </span>
                    ))}
                  </div>
                </div>
              )}
              {assignments.length > 0 && (
                <div>
                  <p className="mb-1.5 text-xs font-medium tracking-wide text-muted-foreground uppercase">
                    Teaching
                  </p>
                  <div className="divide-y divide-border rounded-lg border border-border">
                    {assignments.map((a) => (
                      <div
                        key={a.id}
                        className="flex items-center justify-between px-3 py-2 text-sm"
                      >
                        <span className="font-medium">{a.subject}</span>
                        <span className="text-muted-foreground">{a.label}</span>
                      </div>
                    ))}
                  </div>
                </div>
              )}
            </CardContent>
          )}
        </Card>
      </div>
    );
  }

  // Admin setup progress (real counts). Students land in Phase 3.
  const [{ count: classCount }, { count: teacherCount }] = await Promise.all([
    supabase
      .from("classes")
      .select("id", { count: "exact", head: true })
      .eq("school_id", membership.schoolId),
    supabase
      .from("school_members")
      .select("id", { count: "exact", head: true })
      .eq("school_id", membership.schoolId)
      .eq("role", "teacher"),
  ]);
  const studentCount = 0;

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
    { label: "Invite staff", done: (teacherCount ?? 0) > 0, href: "/settings/staff" },
    { label: "Add students & guardians", done: false, href: "/students" },
  ];
  const remaining = setupSteps.filter((s) => !s.done);

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold tracking-tight">
          Good morning, {firstName}
        </h1>
        <p className="text-muted-foreground">
          {school?.name ?? "Your school"} · {today}
        </p>
      </div>

      {remaining.length > 0 && (
        <Card>
          <CardHeader>
            <CardTitle>Finish setting up {school?.name ?? "your school"}</CardTitle>
            <CardDescription>
              Complete these steps in order to unlock the rest of EduSphere.
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-1">
            {setupSteps.map((step) => (
              <Link
                key={step.label}
                href={step.href}
                className="flex items-center gap-3 rounded-lg px-2 py-2 text-sm hover:bg-muted"
              >
                {step.done ? (
                  <CheckCircle2 className="size-4.5 text-success" />
                ) : (
                  <Circle className="size-4.5 text-muted-foreground" />
                )}
                <span className={step.done ? "text-muted-foreground line-through" : ""}>
                  {step.label}
                </span>
              </Link>
            ))}
          </CardContent>
        </Card>
      )}

      <QuickActions />

      <div className="grid gap-4 sm:grid-cols-3">
        <StatTile label="Total students" value={String(studentCount)} icon={Users} />
        <StatTile label="Attendance % today" value="—" icon={ClipboardCheck} />
        <StatTile label="Pending invoices" value="0" icon={Star} />
      </div>
    </div>
  );
}

function QuickActions() {
  const actions = [
    { href: "/attendance", label: "Mark Attendance", icon: ClipboardCheck },
    { href: "/exams", label: "Add Marks", icon: Star },
    { href: "/notices", label: "Create Announcement", icon: Megaphone },
  ];
  return (
    <div className="grid gap-3 sm:grid-cols-3">
      {actions.map((a) => (
        <Button
          key={a.href}
          asChild
          variant="outline"
          className="h-auto justify-start gap-3 py-4"
        >
          <Link href={a.href}>
            <span className="flex size-9 items-center justify-center rounded-lg bg-secondary text-secondary-foreground">
              <a.icon className="size-4.5" />
            </span>
            <span className="text-left">
              <span className="block font-semibold">{a.label}</span>
            </span>
          </Link>
        </Button>
      ))}
    </div>
  );
}

function StatTile({
  label,
  value,
  icon: Icon,
}: {
  label: string;
  value: string;
  icon: React.ComponentType<{ className?: string }>;
}) {
  return (
    <Card>
      <CardContent className="flex items-center justify-between py-4">
        <div>
          <p className="text-xs font-medium tracking-wide text-muted-foreground uppercase">
            {label}
          </p>
          <p className="text-2xl font-bold">{value}</p>
        </div>
        <span className="flex size-10 items-center justify-center rounded-full bg-secondary text-secondary-foreground">
          <Icon className="size-5" />
        </span>
      </CardContent>
    </Card>
  );
}
