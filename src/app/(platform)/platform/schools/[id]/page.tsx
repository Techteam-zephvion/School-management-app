import Link from "next/link";
import { notFound } from "next/navigation";
import { ArrowLeft, Building2, GraduationCap, Users, BookOpen, Mail } from "lucide-react";
import { createClient } from "@/lib/supabase/server";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Avatar, AvatarFallback } from "@/components/ui/avatar";
import { SchoolStatusToggle } from "../school-status-toggle";

function initials(name: string) {
  return name.split(/\s+/).map((p) => p[0]).slice(0, 2).join("").toUpperCase() || "?";
}

export default async function PlatformSchoolDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const supabase = await createClient();

  const { data: school } = await supabase
    .from("schools")
    .select("id, name, slug, city, state, email, phone, status, created_at")
    .eq("id", id)
    .maybeSingle();
  if (!school) notFound();

  const [{ count: students }, { count: classes }, { data: members }] = await Promise.all([
    supabase.from("students").select("id", { count: "exact", head: true }).eq("school_id", id),
    supabase.from("classes").select("id", { count: "exact", head: true }).eq("school_id", id),
    supabase.from("school_members").select("role, status, profiles(full_name, email)").eq("school_id", id).in("role", ["school_admin", "teacher"]),
  ]);

  const staff = (members ?? []).map((m) => {
    const p = m.profiles as { full_name: string | null; email: string | null } | null;
    return { name: p?.full_name || p?.email || "Invited", email: p?.email ?? "", role: m.role, status: m.status };
  });
  const teacherCount = staff.filter((s) => s.role === "teacher").length;
  const suspended = school.status === "suspended";

  return (
    <div className="mx-auto max-w-3xl space-y-6">
      <Link href="/platform/schools" className="inline-flex items-center gap-1.5 text-sm text-muted-foreground hover:text-foreground">
        <ArrowLeft className="size-4" /> All schools
      </Link>

      <Card className="border-0 shadow-md shadow-muted-foreground/5 ring-1 ring-border/50">
        <CardContent className="flex flex-wrap items-center gap-4 py-5">
          <span className="flex size-14 items-center justify-center rounded-2xl bg-primary/10 text-primary">
            <Building2 className="size-7" />
          </span>
          <div className="min-w-0 flex-1">
            <div className="flex items-center gap-2">
              <h1 className="text-xl font-bold tracking-tight">{school.name}</h1>
              {suspended && <Badge variant="destructive">Suspended</Badge>}
            </div>
            <p className="text-sm text-muted-foreground">
              {[school.city, school.state].filter(Boolean).join(", ") || school.slug}
            </p>
          </div>
          <SchoolStatusToggle schoolId={school.id} suspended={suspended} name={school.name} />
        </CardContent>
      </Card>

      <div className="grid gap-4 sm:grid-cols-3">
        <Metric label="Students" value={String(students ?? 0)} icon={GraduationCap} />
        <Metric label="Teachers" value={String(teacherCount)} icon={Users} />
        <Metric label="Classes" value={String(classes ?? 0)} icon={BookOpen} />
      </div>

      <Card className="overflow-hidden border-0 shadow-md shadow-muted-foreground/5 ring-1 ring-border/50">
        <CardHeader>
          <CardTitle className="text-base">Staff &amp; admins</CardTitle>
        </CardHeader>
        <CardContent className="divide-y divide-border/60 p-0">
          {staff.length === 0 ? (
            <p className="px-5 py-6 text-center text-sm text-muted-foreground">No staff yet.</p>
          ) : (
            staff.map((s, i) => (
              <div key={i} className="flex items-center gap-3 px-5 py-3">
                <Avatar className="size-9">
                  <AvatarFallback>{initials(s.name)}</AvatarFallback>
                </Avatar>
                <div className="min-w-0 flex-1">
                  <p className="truncate text-sm font-medium">{s.name}</p>
                  <p className="flex items-center gap-1 truncate text-xs text-muted-foreground">
                    <Mail className="size-3" /> {s.email}
                  </p>
                </div>
                <Badge variant="secondary" className="capitalize">{s.role.replace("_", " ")}</Badge>
                <Badge variant={s.status === "active" ? "success" : "warning"}>{s.status}</Badge>
              </div>
            ))
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
