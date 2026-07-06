import { redirect } from "next/navigation";
import { CalendarX2 } from "lucide-react";
import { requireActiveMembership, getAuthUser } from "@/lib/auth/session";
import { createClient } from "@/lib/supabase/server";
import { PageHeader } from "@/components/page-header";
import { Card, CardContent } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { CreateLeaveDialog } from "./create-leave-dialog";
import { LeaveActions } from "./leave-actions";

export type StudentPick = { id: string; label: string };
export type LeaveItem = {
  id: string;
  student: string;
  fromDate: string;
  toDate: string;
  reason: string | null;
  status: string;
  canReview: boolean;
};

function fmt(d: string) {
  return new Date(d + "T00:00:00").toLocaleDateString("en-IN", { day: "2-digit", month: "short", year: "numeric" });
}

const STATUS: Record<string, { label: string; variant: "success" | "warning" | "destructive" | "secondary" }> = {
  pending: { label: "Pending", variant: "warning" },
  approved: { label: "Approved", variant: "success" },
  rejected: { label: "Rejected", variant: "destructive" },
  cancelled: { label: "Cancelled", variant: "secondary" },
};

export default async function LeavePage() {
  const membership = await requireActiveMembership();
  if (membership.role === "parent") redirect("/dashboard");
  const supabase = await createClient();
  const schoolId = membership.schoolId;
  const user = await getAuthUser();
  const isAdmin = membership.role === "school_admin";

  const { data: activeYear } = await supabase
    .from("academic_years")
    .select("id")
    .eq("school_id", schoolId)
    .eq("is_active", true)
    .maybeSingle();

  // Students the current user is the class teacher of (or all, for admin) —
  // used both for the "record leave" picker and for review permission.
  const myStudentIds: Set<string> | null = isAdmin ? null : new Set();
  const pickerStudents: StudentPick[] = [];
  if (activeYear) {
    const { data: enrollments } = await supabase
      .from("enrollments")
      .select("student_id, students(first_name, last_name), sections(name, class_teacher_staff_id, classes(name))")
      .eq("school_id", schoolId)
      .eq("academic_year_id", activeYear.id)
      .eq("status", "active");

    let staffId: string | null = null;
    if (!isAdmin) {
      const { data: staff } = await supabase
        .from("staff")
        .select("id")
        .eq("school_id", schoolId)
        .eq("user_id", user?.id ?? "")
        .maybeSingle();
      staffId = staff?.id ?? null;
    }

    for (const e of enrollments ?? []) {
      const sec = e.sections as { name: string; class_teacher_staff_id: string | null; classes: { name: string } | null } | null;
      const mine = isAdmin || (staffId != null && sec?.class_teacher_staff_id === staffId);
      if (!isAdmin && mine) myStudentIds!.add(e.student_id);
      if (mine) {
        const st = e.students as { first_name: string; last_name: string | null } | null;
        if (st)
          pickerStudents.push({
            id: e.student_id,
            label: `${st.first_name} ${st.last_name ?? ""}`.trim() + ` — ${sec?.classes?.name ?? ""} · ${sec?.name ?? ""}`,
          });
      }
    }
    pickerStudents.sort((a, b) => a.label.localeCompare(b.label));
  }

  const { data: leaves } = await supabase
    .from("leave_requests")
    .select("id, student_id, from_date, to_date, reason, status, students(first_name, last_name)")
    .eq("school_id", schoolId)
    .order("created_at", { ascending: false });

  const items: LeaveItem[] = (leaves ?? []).map((l) => {
    const st = l.students as { first_name: string; last_name: string | null } | null;
    return {
      id: l.id,
      student: st ? `${st.first_name} ${st.last_name ?? ""}`.trim() : "Student",
      fromDate: l.from_date,
      toDate: l.to_date,
      reason: l.reason,
      status: l.status,
      canReview: isAdmin || (myStudentIds !== null && myStudentIds.has(l.student_id)),
    };
  });

  return (
    <div className="mx-auto max-w-3xl space-y-6">
      <PageHeader
        title="Leave"
        description="Approve leave and it's marked excused on attendance."
        action={pickerStudents.length > 0 ? <CreateLeaveDialog students={pickerStudents} /> : undefined}
      />

      <Card className="overflow-hidden border-0 shadow-md shadow-muted-foreground/5 ring-1 ring-border/50">
        <CardContent className="divide-y divide-border/60 p-0">
          {items.length === 0 ? (
            <div className="flex flex-col items-center gap-3 py-16 text-center">
              <span className="flex size-12 items-center justify-center rounded-2xl bg-muted/60">
                <CalendarX2 className="size-6 text-muted-foreground/70" />
              </span>
              <p className="text-sm font-medium text-muted-foreground">No leave requests.</p>
              <p className="text-xs text-muted-foreground/70">Parents file leave from their app; you can record and approve here.</p>
            </div>
          ) : (
            items.map((l) => {
              const badge = STATUS[l.status] ?? STATUS.pending;
              return (
                <div key={l.id} className="flex items-center gap-3 px-5 py-3.5">
                  <div className="min-w-0 flex-1">
                    <p className="truncate text-sm font-semibold">{l.student}</p>
                    <p className="truncate text-xs text-muted-foreground">
                      {fmt(l.fromDate)}{l.toDate !== l.fromDate ? ` – ${fmt(l.toDate)}` : ""}
                      {l.reason ? ` · ${l.reason}` : ""}
                    </p>
                  </div>
                  <Badge variant={badge.variant} className="px-2.5 py-1 text-xs font-medium">
                    {badge.label}
                  </Badge>
                  {l.status === "pending" && l.canReview && <LeaveActions id={l.id} student={l.student} />}
                </div>
              );
            })
          )}
        </CardContent>
      </Card>
    </div>
  );
}
