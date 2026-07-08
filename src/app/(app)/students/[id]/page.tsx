import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { ArrowLeft, Cake, Droplet, MapPin, IdCard, GraduationCap } from "lucide-react";
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

  // A student can be managed (edit details + guardians) by an admin, or by the
  // class teacher of the student's current section -- they get the same
  // per-student controls an admin has for the students in their class.
  let canManageStudent = isAdmin;
  if (!isAdmin && enrolled?.sections?.class_teacher_staff_id) {
    const user = await getAuthUser();
    const { data: staff } = await supabase
      .from("staff")
      .select("id")
      .eq("school_id", schoolId)
      .eq("user_id", user?.id ?? "")
      .maybeSingle();
    canManageStudent =
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
    <div className="mx-auto max-w-4xl space-y-6 pb-8">
      {/* Back link */}
      <Link
        href="/students"
        className="inline-flex items-center gap-1.5 text-sm font-medium text-slate-500 transition-colors hover:text-slate-900"
      >
        <ArrowLeft className="size-4" /> All students
      </Link>

      {/* Profile hero card */}
      <Card className="overflow-hidden border border-slate-200/80 bg-white/95 shadow-sm shadow-slate-950/5 ring-1 ring-slate-900/[0.02]">
        <div className="h-1.5 bg-gradient-to-r from-blue-500/60 via-blue-400/40 to-transparent" />
        <CardContent className="flex flex-wrap items-center gap-5 py-6">
          <Avatar className="size-16 ring-2 ring-blue-100">
            <AvatarFallback className="bg-blue-50 text-lg font-bold text-blue-700">
              {`${student.first_name[0] ?? ""}${student.last_name?.[0] ?? ""}`.toUpperCase()}
            </AvatarFallback>
          </Avatar>
          <div className="min-w-0 flex-1">
            <div className="flex items-center gap-2">
              <h1 className="text-xl font-bold tracking-tight text-slate-900">{name}</h1>
              {student.status !== "active" && (
                <Badge variant="warning" className="shrink-0 capitalize">{student.status}</Badge>
              )}
            </div>
            <p className="mt-1 text-sm text-slate-500">
              <span className="font-medium text-slate-600">#{student.admission_no}</span>
              {enrolled?.sections ? (
                <>
                  <span className="mx-1.5 text-slate-300">·</span>
                  {enrolled.sections.classes?.name ?? ""} · {enrolled.sections.name}
                </>
              ) : (
                <>
                  <span className="mx-1.5 text-slate-300">·</span>
                  <span className="text-amber-600">Not enrolled</span>
                </>
              )}
            </p>
          </div>
          {canManageStudent && <EditStudentDialog student={student} />}
        </CardContent>
      </Card>

      {/* Details and Enrollment */}
      <div className="grid gap-6 sm:grid-cols-2">
        <Card className="border border-slate-200/80 bg-white/95 shadow-sm shadow-slate-950/5 ring-1 ring-slate-900/[0.02]">
          <CardHeader className="pb-3">
            <CardTitle className="flex items-center gap-2 text-base font-semibold text-slate-900">
              <span className="flex size-8 items-center justify-center rounded-xl bg-blue-50 text-blue-700 ring-1 ring-blue-100">
                <IdCard className="size-4" />
              </span>
              Details
            </CardTitle>
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

      <GuardiansCard studentId={student.id} guardians={guardians} canEdit={canManageStudent} />
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
    <div className="flex items-start gap-3 rounded-xl border border-slate-100 bg-slate-50/60 px-3.5 py-3">
      <span className="mt-0.5 flex size-8 shrink-0 items-center justify-center rounded-xl bg-white text-slate-500 ring-1 ring-slate-200">
        <Icon className="size-4" />
      </span>
      <div className="min-w-0">
        <p className="text-xs font-medium uppercase tracking-wide text-slate-500">{label}</p>
        <p className="mt-0.5 font-medium text-slate-900 capitalize">{value}</p>
      </div>
    </div>
  );
}
