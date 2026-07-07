"use client";

import {
  Users, GraduationCap, ClipboardCheck, Wallet, Download,
  ReceiptText, Send, ShieldCheck, Activity,
} from "lucide-react";
import type { LucideIcon } from "lucide-react";
import {
  ResponsiveContainer, AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip,
  PieChart, Pie, Cell, BarChart, Bar, LabelList,
} from "recharts";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { formatMoney } from "@/lib/utils";

const ACCENT = "#2563eb";
const FEE_COLORS: Record<string, string> = {
  Paid: "#16a34a",
  Partial: "#f59e0b",
  Unpaid: "#94a3b8",
  Overdue: "#dc2626",
};

type Stats = { students: number; teachers: number; attendancePct: number | null; collected: number; billed: number };
type Activity = { id: string; action: string; actor: string; meta: Record<string, unknown>; at: string };
type InvoiceCsv = { student: string; structure: string; total: number; paid: number; balance: number; status: string };

const ACTION: Record<string, { label: string; icon: LucideIcon }> = {
  payment_recorded: { label: "Payment recorded", icon: ReceiptText },
  results_published: { label: "Results published", icon: Send },
  role_changed: { label: "Role changed", icon: ShieldCheck },
};

function timeago(iso: string) {
  const m = Math.floor((Date.now() - new Date(iso).getTime()) / 60000);
  if (m < 1) return "just now";
  if (m < 60) return `${m}m ago`;
  const h = Math.floor(m / 60);
  if (h < 24) return `${h}h ago`;
  return new Date(iso).toLocaleDateString("en-IN", { day: "2-digit", month: "short" });
}

function activityText(a: Activity): string {
  if (a.action === "payment_recorded") return `${formatMoney(Number(a.meta.amount ?? 0))} via ${String(a.meta.method ?? "cash")}`;
  if (a.action === "results_published") return `Term “${String(a.meta.term ?? "")}”`;
  if (a.action === "role_changed") return `${String(a.meta.from ?? "")} → ${String(a.meta.to ?? "")}`;
  return "";
}

export function ReportsView({
  stats, attendanceTrend, feeStatus, examOverview, activity, invoiceCsv,
}: {
  stats: Stats;
  attendanceTrend: { date: string; pct: number }[];
  feeStatus: { name: string; key: string; value: number }[];
  examOverview: { termName: string; subjects: { subject: string; avg: number }[] } | null;
  activity: Activity[];
  invoiceCsv: InvoiceCsv[];
}) {
  const feeTotal = feeStatus.reduce((s, f) => s + f.value, 0);
  const collectionPct = stats.billed > 0 ? Math.round((stats.collected / stats.billed) * 100) : 0;

  function exportCsv() {
    const header = ["Student", "Fee", "Total", "Paid", "Balance", "Status"];
    const rows = invoiceCsv.map((r) => [r.student, r.structure, r.total, r.paid, r.balance, r.status]);
    const csv = [header, ...rows]
      .map((r) => r.map((c) => `"${String(c).replace(/"/g, '""')}"`).join(","))
      .join("\n");
    const url = URL.createObjectURL(new Blob([csv], { type: "text/csv" }));
    const a = document.createElement("a");
    a.href = url;
    a.download = `fee-collection-${new Date().toISOString().slice(0, 10)}.csv`;
    a.click();
    URL.revokeObjectURL(url);
  }

  return (
    <div className="space-y-6">
      {/* stat tiles */}
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <StatTile label="Students" value={String(stats.students)} icon={Users} />
        <StatTile label="Teachers" value={String(stats.teachers)} icon={GraduationCap} />
        <StatTile label="Attendance today" value={stats.attendancePct === null ? "—" : `${stats.attendancePct}%`} icon={ClipboardCheck} />
        <StatTile label="Fees collected" value={formatMoney(stats.collected)} sub={`${collectionPct}% of ${formatMoney(stats.billed)}`} icon={Wallet} />
      </div>

      <div className="grid gap-6 lg:grid-cols-2">
        {/* attendance trend */}
        <ChartCard title="Attendance %" description="Present + late, last 14 days">
          <ResponsiveContainer width="100%" height={220}>
            <AreaChart data={attendanceTrend} margin={{ top: 8, right: 8, left: -18, bottom: 0 }} className="text-muted-foreground">
              <defs>
                <linearGradient id="att" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="0%" stopColor={ACCENT} stopOpacity={0.28} />
                  <stop offset="100%" stopColor={ACCENT} stopOpacity={0.02} />
                </linearGradient>
              </defs>
              <CartesianGrid vertical={false} stroke="currentColor" strokeOpacity={0.12} />
              <XAxis dataKey="date" tick={{ fill: "currentColor", fontSize: 11 }} tickLine={false} axisLine={false} interval={2} />
              <YAxis domain={[0, 100]} tick={{ fill: "currentColor", fontSize: 11 }} tickLine={false} axisLine={false} width={38} unit="%" />
              <Tooltip
                contentStyle={{ borderRadius: 12, border: "1px solid rgba(0,0,0,0.08)", fontSize: 12 }}
                formatter={(v) => [`${v}%`, "Attendance"]}
              />
              <Area type="monotone" dataKey="pct" stroke={ACCENT} strokeWidth={2} fill="url(#att)" />
            </AreaChart>
          </ResponsiveContainer>
        </ChartCard>

        {/* fee status donut */}
        <ChartCard
          title="Fee collection"
          description="Invoices by status"
          action={
            invoiceCsv.length > 0 ? (
              <Button variant="outline" size="sm" className="gap-1.5" onClick={exportCsv}>
                <Download className="size-4" /> CSV
              </Button>
            ) : undefined
          }
        >
          {feeTotal === 0 ? (
            <EmptyChart label="No invoices yet." />
          ) : (
            <div className="flex flex-col items-center gap-4 sm:flex-row">
              <div className="relative h-[180px] w-[180px] shrink-0">
                <ResponsiveContainer width="100%" height="100%">
                  <PieChart>
                    <Pie data={feeStatus} dataKey="value" nameKey="name" innerRadius={58} outerRadius={82} paddingAngle={2} strokeWidth={2} stroke="var(--color-card)">
                      {feeStatus.map((f) => (
                        <Cell key={f.key} fill={FEE_COLORS[f.name] ?? ACCENT} />
                      ))}
                    </Pie>
                    <Tooltip formatter={(v, n) => [`${v} invoice${Number(v) === 1 ? "" : "s"}`, n as string]} contentStyle={{ borderRadius: 12, fontSize: 12 }} />
                  </PieChart>
                </ResponsiveContainer>
                <div className="pointer-events-none absolute inset-0 flex flex-col items-center justify-center">
                  <span className="text-2xl font-bold">{feeTotal}</span>
                  <span className="text-xs text-muted-foreground">invoices</span>
                </div>
              </div>
              {/* labelled legend (identity is never colour-alone) */}
              <ul className="flex-1 space-y-1.5">
                {feeStatus.map((f) => (
                  <li key={f.key} className="flex items-center gap-2.5 text-sm">
                    <span className="size-3 shrink-0 rounded-sm" style={{ background: FEE_COLORS[f.name] }} aria-hidden />
                    <span className="flex-1">{f.name}</span>
                    <span className="font-semibold tabular-nums">{f.value}</span>
                  </li>
                ))}
              </ul>
            </div>
          )}
        </ChartCard>
      </div>

      {/* exam overview */}
      <ChartCard
        title="Exam overview"
        description={examOverview ? `Average % by subject · ${examOverview.termName}` : "Publish a term's results to see averages"}
      >
        {!examOverview ? (
          <EmptyChart label="No published results yet." />
        ) : (
          <ResponsiveContainer width="100%" height={Math.max(160, examOverview.subjects.length * 44)}>
            <BarChart
              data={examOverview.subjects}
              layout="vertical"
              margin={{ top: 4, right: 40, left: 8, bottom: 4 }}
              className="text-muted-foreground"
            >
              <CartesianGrid horizontal={false} stroke="currentColor" strokeOpacity={0.12} />
              <XAxis type="number" domain={[0, 100]} hide />
              <YAxis type="category" dataKey="subject" tick={{ fill: "currentColor", fontSize: 12 }} tickLine={false} axisLine={false} width={100} />
              <Tooltip formatter={(v) => [`${v}%`, "Average"]} cursor={{ fill: "currentColor", fillOpacity: 0.05 }} contentStyle={{ borderRadius: 12, fontSize: 12 }} />
              <Bar dataKey="avg" fill={ACCENT} radius={[4, 4, 4, 4]} barSize={18}>
                <LabelList dataKey="avg" position="right" formatter={(v) => `${v}%`} className="fill-foreground text-xs font-medium" />
              </Bar>
            </BarChart>
          </ResponsiveContainer>
        )}
      </ChartCard>

      {/* recent activity (audit) */}
      <Card className="overflow-hidden border-0 shadow-md shadow-muted-foreground/5 ring-1 ring-border/50">
        <CardHeader>
          <CardTitle className="text-base">Recent activity</CardTitle>
          <CardDescription>Fees, results and role changes are logged.</CardDescription>
        </CardHeader>
        <CardContent className="divide-y divide-border/60 p-0">
          {activity.length === 0 ? (
            <div className="flex flex-col items-center gap-3 py-10 text-center">
              <span className="flex size-12 items-center justify-center rounded-2xl bg-muted/60">
                <Activity className="size-6 text-muted-foreground/70" />
              </span>
              <p className="text-sm font-medium text-muted-foreground">No activity yet.</p>
            </div>
          ) : (
            activity.map((a) => {
              const meta = ACTION[a.action] ?? { label: a.action, icon: Activity };
              const Icon = meta.icon;
              return (
                <div key={a.id} className="flex items-center gap-3 px-5 py-3">
                  <span className="flex size-9 shrink-0 items-center justify-center rounded-xl bg-primary/10 text-primary">
                    <Icon className="size-4" />
                  </span>
                  <div className="min-w-0 flex-1">
                    <p className="truncate text-sm font-medium">
                      {meta.label} <span className="font-normal text-muted-foreground">{activityText(a)}</span>
                    </p>
                    <p className="truncate text-xs text-muted-foreground">by {a.actor}</p>
                  </div>
                  <span className="shrink-0 text-xs text-muted-foreground">{timeago(a.at)}</span>
                </div>
              );
            })
          )}
        </CardContent>
      </Card>
    </div>
  );
}

function StatTile({ label, value, sub, icon: Icon }: { label: string; value: string; sub?: string; icon: LucideIcon }) {
  return (
    <Card className="border-0 shadow-md shadow-muted-foreground/5 ring-1 ring-border/50">
      <CardContent className="flex items-center justify-between py-4">
        <div className="min-w-0">
          <p className="text-xs font-medium tracking-wide text-muted-foreground uppercase">{label}</p>
          <p className="text-2xl font-bold">{value}</p>
          {sub && <p className="truncate text-xs text-muted-foreground">{sub}</p>}
        </div>
        <span className="flex size-10 shrink-0 items-center justify-center rounded-xl bg-primary/10 text-primary">
          <Icon className="size-5" />
        </span>
      </CardContent>
    </Card>
  );
}

function ChartCard({ title, description, action, children }: { title: string; description?: string; action?: React.ReactNode; children: React.ReactNode }) {
  return (
    <Card className="border-0 shadow-md shadow-muted-foreground/5 ring-1 ring-border/50">
      <CardHeader className="flex-row items-start justify-between space-y-0">
        <div>
          <CardTitle className="text-base">{title}</CardTitle>
          {description && <CardDescription>{description}</CardDescription>}
        </div>
        {action}
      </CardHeader>
      <CardContent>{children}</CardContent>
    </Card>
  );
}

function EmptyChart({ label }: { label: string }) {
  return <div className="flex h-[180px] items-center justify-center text-sm text-muted-foreground">{label}</div>;
}
