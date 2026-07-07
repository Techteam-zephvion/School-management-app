import { redirect } from "next/navigation";
import { requireActiveMembership } from "@/lib/auth/session";
import { createClient } from "@/lib/supabase/server";
import { PageHeader } from "@/components/page-header";
import { ReportsView } from "./reports-view";

function todayISO() {
  return new Date().toISOString().slice(0, 10);
}
function dayKey(d: Date) {
  return d.toISOString().slice(0, 10);
}

export default async function ReportsPage() {
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

  const today = todayISO();
  const since = new Date();
  since.setDate(since.getDate() - 13);
  const sinceISO = dayKey(since);

  const [
    { count: studentCount },
    { count: teacherCount },
    { data: attendance },
    { data: invoices },
    { data: publishedTerms },
  ] = await Promise.all([
    supabase.from("students").select("id", { count: "exact", head: true }).eq("school_id", schoolId),
    supabase.from("school_members").select("id", { count: "exact", head: true }).eq("school_id", schoolId).eq("role", "teacher"),
    supabase.from("attendance").select("date, status").eq("school_id", schoolId).is("subject_id", null).gte("date", sinceISO),
    supabase.from("invoices").select("amount_total, amount_paid, status, due_date, students(first_name, last_name), fee_structures(name)").eq("school_id", schoolId),
    supabase.from("exam_terms").select("id, name").eq("school_id", schoolId).eq("is_published", true).order("published_at", { ascending: false }).limit(1),
  ]);

  // ---- attendance: today % + 14-day trend ----
  const byDate = new Map<string, { present: number; total: number }>();
  for (const a of attendance ?? []) {
    const rec = byDate.get(a.date) ?? { present: 0, total: 0 };
    rec.total += 1;
    if (a.status === "present" || a.status === "late") rec.present += 1;
    byDate.set(a.date, rec);
  }
  const attendanceTrend: { date: string; pct: number }[] = [];
  for (let i = 0; i < 14; i++) {
    const d = new Date(since);
    d.setDate(since.getDate() + i);
    const key = dayKey(d);
    const rec = byDate.get(key);
    attendanceTrend.push({
      date: d.toLocaleDateString("en-IN", { day: "2-digit", month: "short" }),
      pct: rec && rec.total > 0 ? Math.round((rec.present / rec.total) * 100) : 0,
    });
  }
  const todayRec = byDate.get(today);
  const attendancePct = todayRec && todayRec.total > 0 ? Math.round((todayRec.present / todayRec.total) * 100) : null;

  // ---- fees: status breakdown + collection ----
  const invoiceCsv = (invoices ?? []).map((i) => {
    const total = Number(i.amount_total);
    const paid = Number(i.amount_paid);
    let status = i.status as string;
    if (status !== "paid" && status !== "cancelled" && i.due_date < today) status = "overdue";
    const st = i.students as { first_name: string; last_name: string | null } | null;
    return {
      student: st ? `${st.first_name} ${st.last_name ?? ""}`.trim() : "Student",
      structure: (i.fee_structures as { name: string } | null)?.name ?? "Fee",
      total,
      paid,
      balance: total - paid,
      status,
    };
  });
  const collected = invoiceCsv.reduce((sum, r) => sum + r.paid, 0);
  const billed = invoiceCsv.reduce((sum, r) => sum + r.total, 0);
  const feeCounts = invoiceCsv.reduce(
    (acc, r) => {
      if (r.status in acc) acc[r.status] += 1;
      return acc;
    },
    { paid: 0, partial: 0, unpaid: 0, overdue: 0 } as Record<string, number>
  );
  const feeStatus = [
    { name: "Paid", key: "paid", value: feeCounts.paid },
    { name: "Partial", key: "partial", value: feeCounts.partial },
    { name: "Unpaid", key: "unpaid", value: feeCounts.unpaid },
    { name: "Overdue", key: "overdue", value: feeCounts.overdue },
  ].filter((s) => s.value > 0);

  // ---- exams: subject averages for the latest published term ----
  let examOverview: { termName: string; subjects: { subject: string; avg: number }[] } | null = null;
  const term = publishedTerms?.[0];
  if (term) {
    const [{ data: examSubjects }, { data: marks }, { data: subjects }] = await Promise.all([
      supabase.from("exam_subjects").select("id, subject_id, max_marks").eq("term_id", term.id),
      supabase.from("marks").select("exam_subject_id, marks_obtained").eq("term_id", term.id),
      supabase.from("subjects").select("id, name").eq("school_id", schoolId),
    ]);
    const subjectName = new Map((subjects ?? []).map((s) => [s.id, s.name]));
    const esMeta = new Map((examSubjects ?? []).map((e) => [e.id, { subjectId: e.subject_id, max: Number(e.max_marks) }]));
    const acc = new Map<string, { sumPct: number; n: number }>();
    for (const m of marks ?? []) {
      const meta = esMeta.get(m.exam_subject_id);
      if (!meta || meta.max <= 0) continue;
      const pct = (Number(m.marks_obtained) / meta.max) * 100;
      const cur = acc.get(meta.subjectId) ?? { sumPct: 0, n: 0 };
      cur.sumPct += pct;
      cur.n += 1;
      acc.set(meta.subjectId, cur);
    }
    const subjectsArr = [...acc.entries()]
      .map(([sid, v]) => ({ subject: subjectName.get(sid) ?? "Subject", avg: Math.round(v.sumPct / v.n) }))
      .sort((a, b) => b.avg - a.avg);
    if (subjectsArr.length > 0) examOverview = { termName: term.name, subjects: subjectsArr };
  }

  // ---- recent activity ----
  const { data: audit } = await supabase
    .from("audit_logs")
    .select("id, action, entity, meta, created_at, profiles(full_name)")
    .eq("school_id", schoolId)
    .order("created_at", { ascending: false })
    .limit(12);
  const activity = (audit ?? []).map((a) => ({
    id: a.id,
    action: a.action,
    actor: (a.profiles as { full_name: string | null } | null)?.full_name ?? "System",
    meta: a.meta as Record<string, unknown>,
    at: a.created_at,
  }));

  return (
    <div className="mx-auto max-w-5xl space-y-6">
      <PageHeader title="Reports" description={`Overview for ${membership.schoolName}${activeYear ? ` · ${activeYear.name}` : ""}.`} />
      <ReportsView
        stats={{
          students: studentCount ?? 0,
          teachers: teacherCount ?? 0,
          attendancePct,
          collected,
          billed,
        }}
        attendanceTrend={attendanceTrend}
        feeStatus={feeStatus}
        examOverview={examOverview}
        activity={activity}
        invoiceCsv={invoiceCsv}
      />
    </div>
  );
}
