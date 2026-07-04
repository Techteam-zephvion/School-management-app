import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { ArrowLeft, Cake, Droplet, MapPin, IdCard } from "lucide-react";
import { requireActiveMembership, getAuthUser } from "@/lib/auth/session";
import { createClient } from "@/lib/supabase/server";
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Avatar, AvatarFallback } from "@/components/ui/avatar";
import { EditStudentDialog } from "./edit-student-dialog";
import { EnrollCard } from "./enroll-card";
import { GuardiansCard } from "./guardians-card";

function fmtDate(d: string | null) {
  return d ? new Date(d).toLocaleDateString("en-IN", { day: "2-digit", month: "short", year: "numeric" }) : "—";
}

export default async function StudentProfilePage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const membership = await requireActiveMembership();
  if (membership.role === "parent") redirect("/dashboard");
  const supabase = await createClient();
  const schoolId = membership.schoolId;
  const isAdmin = membership.role === "school_admin";

  const { data: student } = await supabase
    .from("students")
    .select("*")
    .eq("id", id)
    .eq("school_id", schoolId)
    .maybeSingle();
  if (!student) notFound();

  const { data: activeYear } = await supabase
    .from("academic_years")
    .select("id, name")
    .eq("school_id", schoolId)
    .eq("is_active", true)
    .maybeSingle();

  const [{ data: enrollment }, { data: guardianLinks }, { data: sections }] = await Promise.all([
    activeYear
      ? supabase
          .from("enrollments")
          .select("id, roll_no, sections(id, name, class_teacher_staff_id, classes(name))")
          .eq("student_id", id)
          .eq("academic_year_id", activeYear.id)
          .eq("status", "active")
          .maybeSingle()
      : Promise.resolve({ data: null }),
    supabase
      .from("student_guardians")
      .select("id, relation, is_primary, guardian_user_id, profiles(full_name, email)")
      .eq("student_id", id)
      .order("is_primary", { ascending: false }),
    activeYear
      ? supabase
          .from("sections")
          .select("id, name, classes(name)")
          .eq("school_id", schoolId)
          .eq("academic_year_id", activeYear.id)
          .order("name")
      : Promise.resolve({ data: [] as { id: string; name: string; classes: { name: string } | null }[] }),
  ]);

  // Guardian membership status (invited/active) in this school.
  const guardianIds = (guardianLinks ?? []).map((g) => g.guardian_user_id);
  const statusByUser = new Map<string, string>();
  if (guardianIds.length > 0) {
    const { data: members } = await supabase
      .from("school_members")
      .select("user_id, status")
      .eq("school_id", schoolId)
      .in("user_id", guardianIds);
    for (const m of members ?? []) statusByUser.set(m.user_id, m.status);
  }

  const enrolled = enrollment as
    | {
        id: string;
        roll_no: string | null;
        sections: {
          id: string;
          name: string;
          class_teacher_staff_id: string | null;
          classes: { name: string } | null;
        } | null;
      }
    | null;

  // Guardians can be managed by an admin, or by the class teacher of the
  // student's current section (they own their class's parent relationships).
  let canManageGuardians = isAdmin;
  if (!isAdmin && enrolled?.sections?.class_teacher_staff_id) {
    const user = await getAuthUser();
    const { data: staff } = await supabase
      .from("staff")
      .select("id")
      .eq("school_id", schoolId)
      .eq("user_id", user?.id ?? "")
      .maybeSingle();
    canManageGuardians =
      Boolean(staff) && enrolled.sections.class_teacher_staff_id === staff!.id;
  }
  const sectionOptions = (sections ?? []).map((s) => ({
    id: s.id,
    label: `${(s.classes as { name: string } | null)?.name ?? ""} · ${s.name}`,
  }));
  const guardians = (guardianLinks ?? []).map((g) => {
    const profile = g.profiles as { full_name: string | null; email: string | null } | null;
    return {
      id: g.id,
      name: profile?.full_name || profile?.email || "Guardian",
      email: profile?.email ?? "",
      relation: g.relation,
      isPrimary: g.is_primary,
      status: statusByUser.get(g.guardian_user_id) ?? "invited",
    };
  });

  const name = `${student.first_name} ${student.last_name ?? ""}`.trim();

  return (
    <div className="mx-auto max-w-3xl space-y-6">
      <Link
        href="/students"
        className="inline-flex items-center gap-1.5 text-sm text-muted-foreground hover:text-foreground"
      >
        <ArrowLeft className="size-4" /> All students
      </Link>

      <Card>
        <CardContent className="flex flex-wrap items-center gap-4 py-5">
          <Avatar className="size-16">
            <AvatarFallback className="text-lg">
              {`${student.first_name[0] ?? ""}${student.last_name?.[0] ?? ""}`.toUpperCase()}
            </AvatarFallback>
          </Avatar>
          <div className="min-w-0 flex-1">
            <div className="flex items-center gap-2">
              <h1 className="text-xl font-bold tracking-tight">{name}</h1>
              {student.status !== "active" && (
                <Badge variant="warning" className="capitalize">{student.status}</Badge>
              )}
            </div>
            <p className="text-sm text-muted-foreground">
              #{student.admission_no}
              {enrolled?.sections
                ? ` · ${enrolled.sections.classes?.name ?? ""} · ${enrolled.sections.name}`
                : " · Not enrolled"}
            </p>
          </div>
          {isAdmin && <EditStudentDialog student={student} />}
        </CardContent>
      </Card>

      <div className="grid gap-6 sm:grid-cols-2">
        <Card>
          <CardHeader>
            <CardTitle>Details</CardTitle>
          </CardHeader>
          <CardContent className="space-y-3 text-sm">
            <Detail icon={IdCard} label="Gender" value={student.gender ?? "—"} />
            <Detail icon={Cake} label="Date of birth" value={fmtDate(student.dob)} />
            <Detail icon={Droplet} label="Blood group" value={student.blood_group ?? "—"} />
            <Detail icon={MapPin} label="Address" value={student.address ?? "—"} />
          </CardContent>
        </Card>

        <EnrollCard
          studentId={student.id}
          currentSectionLabel={
            enrolled?.sections
              ? `${enrolled.sections.classes?.name ?? ""} · ${enrolled.sections.name}`
              : null
          }
          currentRollNo={enrolled?.roll_no ?? null}
          sections={sectionOptions}
          hasActiveYear={Boolean(activeYear)}
          yearName={activeYear?.name ?? null}
          canEdit={isAdmin}
        />
      </div>

      <GuardiansCard studentId={student.id} guardians={guardians} canEdit={canManageGuardians} />
    </div>
  );
}

function Detail({
  icon: Icon,
  label,
  value,
}: {
  icon: React.ComponentType<{ className?: string }>;
  label: string;
  value: string;
}) {
  return (
    <div className="flex items-start gap-2.5">
      <Icon className="mt-0.5 size-4 shrink-0 text-muted-foreground" />
      <div>
        <p className="text-xs text-muted-foreground">{label}</p>
        <p className="font-medium capitalize">{value}</p>
      </div>
    </div>
  );
}
