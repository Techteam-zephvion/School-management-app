import Link from "next/link";
import { Building2, Users, GraduationCap, ChevronRight, School } from "lucide-react";
import { createClient } from "@/lib/supabase/server";
import { PageHeader } from "@/components/page-header";
import { Card, CardContent } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { CreateSchoolDialog } from "./create-school-dialog";
import { SchoolStatusToggle } from "./school-status-toggle";

function fmt(d: string) {
  return new Date(d).toLocaleDateString("en-IN", { day: "2-digit", month: "short", year: "numeric" });
}

export default async function PlatformSchoolsPage() {
  const supabase = await createClient();

  const [{ data: schools }, { data: students }, { data: members }] = await Promise.all([
    supabase.from("schools").select("id, name, slug, city, status, created_at").order("created_at", { ascending: false }),
    supabase.from("students").select("school_id"),
    supabase.from("school_members").select("school_id, role").eq("status", "active"),
  ]);

  const studentsBySchool = new Map<string, number>();
  for (const s of students ?? []) studentsBySchool.set(s.school_id, (studentsBySchool.get(s.school_id) ?? 0) + 1);
  const staffBySchool = new Map<string, number>();
  let totalUsers = 0;
  for (const m of members ?? []) {
    totalUsers += 1;
    if (m.role === "teacher" || m.role === "school_admin")
      staffBySchool.set(m.school_id, (staffBySchool.get(m.school_id) ?? 0) + 1);
  }

  return (
    <div className="mx-auto max-w-4xl space-y-6">
      <PageHeader
        title="Schools"
        description="Every school on EduSphere."
        action={<CreateSchoolDialog />}
      />

      <div className="grid gap-4 sm:grid-cols-3">
        <Metric label="Schools" value={String(schools?.length ?? 0)} icon={Building2} />
        <Metric label="Students" value={String(students?.length ?? 0)} icon={GraduationCap} />
        <Metric label="Active users" value={String(totalUsers)} icon={Users} />
      </div>

      <Card className="overflow-hidden border-0 shadow-md shadow-muted-foreground/5 ring-1 ring-border/50">
        <CardContent className="divide-y divide-border/60 p-0">
          {!schools || schools.length === 0 ? (
            <div className="flex flex-col items-center gap-3 py-16 text-center">
              <span className="flex size-12 items-center justify-center rounded-2xl bg-muted/60">
                <School className="size-6 text-muted-foreground/70" />
              </span>
              <p className="text-sm font-medium text-muted-foreground">No schools yet.</p>
              <p className="text-xs text-muted-foreground/70">Onboard your first school above.</p>
            </div>
          ) : (
            schools.map((s) => {
              const suspended = s.status === "suspended";
              return (
                <div key={s.id} className="flex items-center gap-4 px-5 py-4">
                  <Link href={`/platform/schools/${s.id}`} className="group flex min-w-0 flex-1 items-center gap-4">
                    <span className="flex size-10 shrink-0 items-center justify-center rounded-xl bg-primary/10 text-primary transition-colors group-hover:bg-primary/15">
                      <Building2 className="size-5" />
                    </span>
                    <div className="min-w-0 flex-1">
                      <p className="flex items-center gap-2 truncate text-sm font-semibold">
                        {s.name}
                        {suspended && <Badge variant="destructive" className="px-2 py-0 text-[11px]">Suspended</Badge>}
                      </p>
                      <p className="truncate text-xs text-muted-foreground">
                        {s.city ? `${s.city} · ` : ""}
                        {studentsBySchool.get(s.id) ?? 0} students · {staffBySchool.get(s.id) ?? 0} staff · since {fmt(s.created_at)}
                      </p>
                    </div>
                  </Link>
                  <SchoolStatusToggle schoolId={s.id} suspended={suspended} name={s.name} />
                  <Link href={`/platform/schools/${s.id}`} aria-label="Open school" className="text-muted-foreground hover:text-foreground">
                    <ChevronRight className="size-4" />
                  </Link>
                </div>
              );
            })
          )}
        </CardContent>
      </Card>
    </div>
  );
}

function Metric({ label, value, icon: Icon }: { label: string; value: string; icon: typeof Building2 }) {
  return (
    <Card className="border-0 shadow-md shadow-muted-foreground/5 ring-1 ring-border/50">
      <CardContent className="flex items-center justify-between py-4">
        <div>
          <p className="text-xs font-medium tracking-wide text-muted-foreground uppercase">{label}</p>
          <p className="text-2xl font-bold">{value}</p>
        </div>
        <span className="flex size-10 items-center justify-center rounded-xl bg-primary/10 text-primary">
          <Icon className="size-5" />
        </span>
      </CardContent>
    </Card>
  );
}
