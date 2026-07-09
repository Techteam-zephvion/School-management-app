"use client";

import type { ComponentType, ReactNode } from "react";
import {
  Users,
  GraduationCap,
  ClipboardCheck,
  Wallet,
  Download,
  ReceiptText,
  Send,
  ShieldCheck,
  Activity,
  TrendingUp,
  PieChart as PieIcon,
  BarChart3,
  Layers,
  AlertTriangle,
} from "lucide-react";
import type { LucideIcon } from "lucide-react";
import {
  ResponsiveContainer,
  AreaChart,
  Area,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  PieChart,
  Pie,
  Cell,
  BarChart,
  Bar,
  LabelList,
} from "recharts";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { cn, formatMoney } from "@/lib/utils";

type IconComponent = ComponentType<{ className?: string }>;
type Tone = "blue" | "cyan" | "emerald" | "amber";

const ACCENT = "#2563eb";
const AXIS = "#94a3b8";
const FEE_COLORS: Record<string, string> = {
  Paid: "#059669",
  Partial: "#d97706",
  Unpaid: "#94a3b8",
  Overdue: "#dc2626",
};

const toneStyles: Record<Tone, { icon: string; panel: string; border: string; progress: string }> = {
  blue: { icon: "bg-blue-50 text-blue-700 ring-blue-100", panel: "from-blue-50 to-white", border: "border-blue-100", progress: "bg-blue-600" },
  cyan: { icon: "bg-cyan-50 text-cyan-700 ring-cyan-100", panel: "from-cyan-50 to-white", border: "border-cyan-100", progress: "bg-cyan-600" },
  emerald: { icon: "bg-emerald-50 text-emerald-700 ring-emerald-100", panel: "from-emerald-50 to-white", border: "border-emerald-100", progress: "bg-emerald-600" },
  amber: { icon: "bg-amber-50 text-amber-700 ring-amber-100", panel: "from-amber-50 to-white", border: "border-amber-100", progress: "bg-amber-500" },
};

type Stats = { students: number; teachers: number; attendancePct: number | null; attendanceAvg: number | null; collected: number; billed: number };
type ActivityRow = { id: string; action: string; actor: string; meta: Record<string, unknown>; at: string };
type InvoiceCsv = { student: string; structure: string; total: number; paid: number; balance: number; status: string };

const ACTION: Record<string, { label: string; icon: LucideIcon }> = {
  payment_recorded: { label: "Payment recorded", icon: ReceiptText },
  results_published: { label: "Results published", icon: Send },
  role_changed: { label: "Role changed", icon: ShieldCheck },
};
const STATUS_BADGE: Record<string, "success" | "warning" | "secondary" | "destructive"> = {
  paid: "success",
  partial: "warning",
  unpaid: "secondary",
  overdue: "destructive",
};

function timeago(iso: string) {
  const m = Math.floor((Date.now() - new Date(iso).getTime()) / 60000);
  if (m < 1) return "just now";
  if (m < 60) return `${m}m ago`;
  const h = Math.floor(m / 60);
  if (h < 24) return `${h}h ago`;
  return new Date(iso).toLocaleDateString("en-IN", { day: "2-digit", month: "short" });
}
function activityText(a: ActivityRow): string {
  if (a.action === "payment_recorded") return `${formatMoney(Number(a.meta.amount ?? 0))} via ${String(a.meta.method ?? "cash")}`;
  if (a.action === "results_published") return `Term “${String(a.meta.term ?? "")}”`;
  if (a.action === "role_changed") return `${String(a.meta.from ?? "")} → ${String(a.meta.to ?? "")}`;
  return "";
}
function initials(name: string) {
  return name.split(/\s+/).map((p) => p[0]).slice(0, 2).join("").toUpperCase() || "?";
}
function attendanceTone(pct: number | null): Tone {
  if (pct == null) return "blue";
  if (pct >= 85) return "emerald";
  if (pct < 70) return "amber";
  return "blue";
}

export function ReportsView({
  schoolName,
  yearName,
  stats,
  attendanceTrend,
  feeStatus,
  examOverview,
  enrollmentByClass,
  activity,
  invoiceCsv,
}: {
  schoolName: string;
  yearName: string | null;
  stats: Stats;
  attendanceTrend: { date: string; pct: number }[];
  feeStatus: { name: string; key: string; value: number }[];
  examOverview: { termName: string; subjects: { subject: string; avg: number }[] } | null;
  enrollmentByClass: { className: string; count: number }[];
  activity: ActivityRow[];
  invoiceCsv: InvoiceCsv[];
}) {
  const feeTotal = feeStatus.reduce((s, f) => s + f.value, 0);
  const collectionPct = stats.billed > 0 ? Math.round((stats.collected / stats.billed) * 100) : 0;
  const outstanding = invoiceCsv
    .filter((r) => r.balance > 0)
    .sort((a, b) => b.balance - a.balance)
    .slice(0, 6);
  const outstandingTotal = invoiceCsv.reduce((s, r) => s + Math.max(0, r.balance), 0);
  const maxEnroll = Math.max(1, ...enrollmentByClass.map((c) => c.count));

  function exportCsv() {
    const header = ["Student", "Fee", "Total", "Paid", "Balance", "Status"];
    const rows = invoiceCsv.map((r) => [r.student, r.structure, r.total, r.paid, r.balance, r.status]);
    const csv = [header, ...rows].map((r) => r.map((c) => `"${String(c).replace(/"/g, '""')}"`).join(",")).join("\n");
    const url = URL.createObjectURL(new Blob([csv], { type: "text/csv" }));
    const a = document.createElement("a");
    a.href = url;
    a.download = `fee-collection-${new Date().toISOString().slice(0, 10)}.csv`;
    a.click();
    URL.revokeObjectURL(url);
  }

  return (
    <div className="space-y-6">
      {/* header */}
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <h1 className="text-2xl font-bold tracking-tight text-slate-950">Reports</h1>
          <p className="mt-0.5 text-sm text-slate-500">
            Overview for {schoolName}
            {yearName ? ` · ${yearName}` : ""}.
          </p>
        </div>
        <Button
          variant="outline"
          className="h-10 gap-2 border-slate-200 bg-white text-slate-700 hover:border-blue-200 hover:bg-blue-50 hover:text-blue-700"
          onClick={exportCsv}
          disabled={invoiceCsv.length === 0}
        >
          <Download className="size-4" /> Export fees CSV
        </Button>
      </div>

      {/* KPI row */}
      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <MetricCard label="Students" value={String(stats.students)} sub="Enrolled this year" icon={GraduationCap} tone="blue" />
        <MetricCard label="Teachers" value={String(stats.teachers)} sub="Active staff" icon={Users} tone="cyan" />
        <MetricCard
          label="Attendance today"
          value={stats.attendancePct === null ? "—" : `${stats.attendancePct}%`}
          sub={stats.attendanceAvg === null ? "No data yet" : `${stats.attendanceAvg}% avg · 14 days`}
          icon={ClipboardCheck}
          tone={attendanceTone(stats.attendancePct)}
          progress={stats.attendancePct ?? undefined}
        />
        <MetricCard
          label="Fees collected"
          value={formatMoney(stats.collected)}
          sub={`${collectionPct}% of ${formatMoney(stats.billed)}`}
          icon={Wallet}
          tone="emerald"
          progress={collectionPct}
        />
      </div>

      {/* attendance trend + fee donut */}
      <div className="grid gap-6 lg:grid-cols-3">
        <SectionCard icon={TrendingUp} title="Attendance trend" eyebrow="Last 14 days" className="lg:col-span-2">
          <ResponsiveContainer width="100%" height={240}>
            <AreaChart data={attendanceTrend} margin={{ top: 8, right: 8, left: -18, bottom: 0 }}>
              <defs>
                <linearGradient id="att" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="0%" stopColor={ACCENT} stopOpacity={0.25} />
                  <stop offset="100%" stopColor={ACCENT} stopOpacity={0.02} />
                </linearGradient>
              </defs>
              <CartesianGrid vertical={false} stroke="#e2e8f0" />
              <XAxis dataKey="date" tick={{ fill: AXIS, fontSize: 11 }} tickLine={false} axisLine={false} interval={2} />
              <YAxis domain={[0, 100]} tick={{ fill: AXIS, fontSize: 11 }} tickLine={false} axisLine={false} width={38} unit="%" />
              <Tooltip
                contentStyle={{ borderRadius: 12, border: "1px solid #e2e8f0", fontSize: 12, boxShadow: "0 4px 12px rgba(2,6,23,0.06)" }}
                formatter={(v) => [`${v}%`, "Attendance"]}
              />
              <Area type="monotone" dataKey="pct" stroke={ACCENT} strokeWidth={2.5} fill="url(#att)" dot={false} activeDot={{ r: 4 }} />
            </AreaChart>
          </ResponsiveContainer>
        </SectionCard>

        <SectionCard icon={PieIcon} title="Fee status" eyebrow="By invoice">
          {feeTotal === 0 ? (
            <EmptyState icon={PieIcon} label="No invoices yet." />
          ) : (
            <div className="flex flex-col items-center gap-4">
              <div className="relative h-[168px] w-[168px] shrink-0">
                <ResponsiveContainer width="100%" height="100%">
                  <PieChart>
                    <Pie data={feeStatus} dataKey="value" nameKey="name" innerRadius={54} outerRadius={80} paddingAngle={2} strokeWidth={2} stroke="#ffffff">
                      {feeStatus.map((f) => (
                        <Cell key={f.key} fill={FEE_COLORS[f.name] ?? ACCENT} />
                      ))}
                    </Pie>
                    <Tooltip formatter={(v, n) => [`${v} invoice${Number(v) === 1 ? "" : "s"}`, n as string]} contentStyle={{ borderRadius: 12, border: "1px solid #e2e8f0", fontSize: 12 }} />
                  </PieChart>
                </ResponsiveContainer>
                <div className="pointer-events-none absolute inset-0 flex flex-col items-center justify-center">
                  <span className="text-2xl font-bold text-slate-950">{feeTotal}</span>
                  <span className="text-xs text-slate-500">invoices</span>
                </div>
              </div>
              <ul className="w-full space-y-1.5">
                {feeStatus.map((f) => (
                  <li key={f.key} className="flex items-center gap-2.5 text-sm">
                    <span className="size-3 shrink-0 rounded-sm" style={{ background: FEE_COLORS[f.name] }} aria-hidden />
                    <span className="flex-1 text-slate-600">{f.name}</span>
                    <span className="font-semibold tabular-nums text-slate-900">{f.value}</span>
                  </li>
                ))}
              </ul>
            </div>
          )}
        </SectionCard>
      </div>

      {/* exam overview + outstanding fees */}
      <div className="grid gap-6 lg:grid-cols-3">
        <SectionCard
          icon={BarChart3}
          title="Exam performance"
          eyebrow={examOverview ? examOverview.termName : "No published term"}
          className="lg:col-span-2"
        >
          {!examOverview ? (
            <EmptyState icon={BarChart3} label="Publish a term's results to see subject averages." />
          ) : (
            <ResponsiveContainer width="100%" height={Math.max(170, examOverview.subjects.length * 46)}>
              <BarChart data={examOverview.subjects} layout="vertical" margin={{ top: 4, right: 44, left: 8, bottom: 4 }}>
                <CartesianGrid horizontal={false} stroke="#e2e8f0" />
                <XAxis type="number" domain={[0, 100]} hide />
                <YAxis type="category" dataKey="subject" tick={{ fill: "#475569", fontSize: 12 }} tickLine={false} axisLine={false} width={110} />
                <Tooltip formatter={(v) => [`${v}%`, "Average"]} cursor={{ fill: "#2563eb", fillOpacity: 0.05 }} contentStyle={{ borderRadius: 12, border: "1px solid #e2e8f0", fontSize: 12 }} />
                <Bar dataKey="avg" fill={ACCENT} radius={[6, 6, 6, 6]} barSize={18}>
                  <LabelList dataKey="avg" position="right" formatter={(v) => `${v}%`} className="fill-slate-700 text-xs font-semibold" />
                </Bar>
              </BarChart>
            </ResponsiveContainer>
          )}
        </SectionCard>

        <SectionCard
          icon={AlertTriangle}
          title="Outstanding fees"
          eyebrow={outstandingTotal > 0 ? `${formatMoney(outstandingTotal)} pending` : "All settled"}
        >
          {outstanding.length === 0 ? (
            <EmptyState icon={Wallet} label="No pending balances." />
          ) : (
            <ul className="space-y-1.5">
              {outstanding.map((r, i) => (
                <li key={`${r.student}-${i}`} className="flex items-center gap-3 rounded-xl border border-slate-200/70 px-3 py-2.5">
                  <span className="flex size-9 shrink-0 items-center justify-center rounded-full bg-blue-50 text-xs font-semibold text-blue-700 ring-1 ring-blue-100">
                    {initials(r.student)}
                  </span>
                  <div className="min-w-0 flex-1">
                    <p className="truncate text-sm font-medium text-slate-900">{r.student}</p>
                    <p className="truncate text-xs text-slate-500">{r.structure}</p>
                  </div>
                  <div className="flex flex-col items-end gap-1">
                    <span className="text-sm font-semibold tabular-nums text-slate-900">{formatMoney(r.balance)}</span>
                    <Badge variant={STATUS_BADGE[r.status] ?? "secondary"} className="capitalize">{r.status}</Badge>
                  </div>
                </li>
              ))}
            </ul>
          )}
        </SectionCard>
      </div>

      {/* enrollment by class + recent activity */}
      <div className="grid gap-6 lg:grid-cols-2">
        <SectionCard icon={Layers} title="Enrollment by class" eyebrow={`${stats.students} students`}>
          {enrollmentByClass.length === 0 ? (
            <EmptyState icon={Layers} label="No enrolled students yet." />
          ) : (
            <div className="space-y-3.5">
              {enrollmentByClass.map((c) => (
                <div key={c.className} className="space-y-1.5">
                  <div className="flex items-center justify-between text-sm">
                    <span className="truncate font-medium text-slate-700">{c.className}</span>
                    <span className="shrink-0 font-semibold tabular-nums text-slate-900">{c.count}</span>
                  </div>
                  <div className="h-2 overflow-hidden rounded-full bg-slate-100">
                    <div className="h-full rounded-full bg-blue-500" style={{ width: `${(c.count / maxEnroll) * 100}%` }} />
                  </div>
                </div>
              ))}
            </div>
          )}
        </SectionCard>

        <SectionCard icon={Activity} title="Recent activity" eyebrow="Fees · results · roles">
          {activity.length === 0 ? (
            <EmptyState icon={Activity} label="No activity yet." />
          ) : (
            <div className="-mx-2 divide-y divide-slate-100">
              {activity.map((a) => {
                const meta = ACTION[a.action] ?? { label: a.action, icon: Activity };
                const Icon = meta.icon;
                return (
                  <div key={a.id} className="flex items-center gap-3 px-2 py-2.5">
                    <span className="flex size-9 shrink-0 items-center justify-center rounded-xl bg-blue-50 text-blue-700 ring-1 ring-blue-100">
                      <Icon className="size-4" />
                    </span>
                    <div className="min-w-0 flex-1">
                      <p className="truncate text-sm font-medium text-slate-900">
                        {meta.label} <span className="font-normal text-slate-500">{activityText(a)}</span>
                      </p>
                      <p className="truncate text-xs text-slate-500">by {a.actor}</p>
                    </div>
                    <span className="shrink-0 text-xs text-slate-400">{timeago(a.at)}</span>
                  </div>
                );
              })}
            </div>
          )}
        </SectionCard>
      </div>
    </div>
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
  const pct = progress == null ? null : Math.min(100, Math.max(0, progress));
  return (
    <div className={cn("rounded-2xl border bg-gradient-to-br p-4 shadow-sm shadow-slate-950/5 transition-all motion-safe:hover:-translate-y-0.5 hover:shadow-md", styles.panel, styles.border)}>
      <div className="flex items-start justify-between gap-3">
        <div className="min-w-0">
          <p className="text-xs font-semibold tracking-wide text-slate-500 uppercase">{label}</p>
          <p className="mt-1 truncate text-2xl font-bold text-slate-950">{value}</p>
          {sub && <p className="mt-1 truncate text-xs text-slate-500">{sub}</p>}
        </div>
        <span className={cn("flex size-11 shrink-0 items-center justify-center rounded-2xl ring-1", styles.icon)}>
          <Icon className="size-5" />
        </span>
      </div>
      {pct != null && (
        <div className="mt-4 h-2 overflow-hidden rounded-full bg-slate-200/70">
          <div className={cn("h-full rounded-full", styles.progress)} style={{ width: `${pct}%` }} />
        </div>
      )}
    </div>
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
  action?: ReactNode;
  className?: string;
  children: ReactNode;
}) {
  return (
    <Card className={cn("overflow-hidden border border-slate-200/80 bg-white/95 shadow-sm shadow-slate-950/5 ring-1 ring-slate-900/[0.02]", className)}>
      <CardHeader className="flex flex-row items-start justify-between gap-3 space-y-0 pb-4">
        <div className="flex min-w-0 items-start gap-3">
          <span className="flex size-10 shrink-0 items-center justify-center rounded-2xl bg-blue-50 text-blue-700 ring-1 ring-blue-100">
            <Icon className="size-5" />
          </span>
          <div className="min-w-0">
            {eyebrow && <p className="truncate text-xs font-semibold tracking-wide text-slate-500 uppercase">{eyebrow}</p>}
            <CardTitle className="mt-0.5 truncate text-base text-slate-950">{title}</CardTitle>
          </div>
        </div>
        {action}
      </CardHeader>
      <CardContent className="pt-0">{children}</CardContent>
    </Card>
  );
}

function EmptyState({ icon: Icon, label }: { icon: IconComponent; label: string }) {
  return (
    <div className="flex flex-col items-center gap-3 py-10 text-center">
      <span className="flex size-12 items-center justify-center rounded-2xl bg-slate-50 text-slate-400 ring-1 ring-slate-200">
        <Icon className="size-5" />
      </span>
      <p className="max-w-[16rem] text-sm text-slate-500">{label}</p>
    </div>
  );
}
