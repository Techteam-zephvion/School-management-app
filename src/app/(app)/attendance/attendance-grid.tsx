"use client";

import { useState, useTransition } from "react";
import { toast } from "sonner";
import { Check, Loader2, Users } from "lucide-react";
import { saveAttendance, type AttendStatus } from "@/lib/actions/attendance";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";

type Student = { id: string; name: string; status: AttendStatus | null };

const OPTIONS: { value: AttendStatus; label: string; active: string; ring: string }[] = [
  {
    value: "present",
    label: "P",
    active: "bg-emerald-500 text-white border-emerald-500 shadow-sm shadow-emerald-200",
    ring: "ring-emerald-200",
  },
  {
    value: "absent",
    label: "A",
    active: "bg-red-500 text-white border-red-500 shadow-sm shadow-red-200",
    ring: "ring-red-200",
  },
  {
    value: "late",
    label: "L",
    active: "bg-amber-500 text-white border-amber-500 shadow-sm shadow-amber-200",
    ring: "ring-amber-200",
  },
  {
    value: "excused",
    label: "E",
    active: "bg-blue-500 text-white border-blue-500 shadow-sm shadow-blue-200",
    ring: "ring-blue-200",
  },
];

function initials(name: string) {
  return name.split(/\s+/).map((p) => p[0]).slice(0, 2).join("").toUpperCase() || "?";
}

export function AttendanceGrid({
  sectionId,
  subjectId,
  date,
  label,
  students,
}: {
  sectionId: string;
  subjectId: string | null;
  date: string;
  label: string;
  students: Student[];
}) {
  // Default everyone to present (fast path: flip only the absentees).
  const [statuses, setStatuses] = useState<Record<string, AttendStatus>>(() =>
    Object.fromEntries(students.map((s) => [s.id, s.status ?? "present"]))
  );
  const [isPending, startTransition] = useTransition();

  const alreadyMarked = students.some((s) => s.status !== null);
  const present = Object.values(statuses).filter((s) => s === "present").length;
  const absent = Object.values(statuses).filter((s) => s === "absent").length;
  const late = Object.values(statuses).filter((s) => s === "late").length;
  const excused = Object.values(statuses).filter((s) => s === "excused").length;

  function setAll(status: AttendStatus) {
    setStatuses(Object.fromEntries(students.map((s) => [s.id, status])));
  }

  function save() {
    startTransition(async () => {
      const result = await saveAttendance({
        sectionId,
        subjectId,
        date,
        marks: students.map((s) => ({ studentId: s.id, status: statuses[s.id] })),
      });
      if (result?.error) toast.error(result.error);
      else toast.success("Attendance saved.");
    });
  }

  return (
    <div className="overflow-hidden rounded-2xl border border-slate-200/80 bg-white/95 shadow-sm shadow-slate-950/5 ring-1 ring-slate-900/[0.02]">
      {/* Header */}
      <div className="border-b border-slate-100 px-5 py-4">
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div className="flex min-w-0 items-start gap-3">
            <span className="mt-3 flex size-10 shrink-0 items-center justify-center rounded-2xl bg-blue-50 text-blue-700 ring-1 ring-blue-100">
              <Users className="size-5" />
            </span>
            <div className="min-w-0">
              <p className="text-xs font-semibold uppercase tracking-wide text-slate-500">
                Attendance register
              </p>
              <h3 className="mt-0.5 truncate text-base font-semibold text-slate-900">{label}</h3>
              <p className="mt-0.5 text-xs text-slate-500">
                {new Date(date + "T00:00:00").toLocaleDateString("en-IN", {
                  weekday: "long",
                  day: "numeric",
                  month: "long",
                })}
                {alreadyMarked ? (
                  <span className="ml-1.5 text-amber-600">(previously marked — editing)</span>
                ) : null}
              </p>
            </div>
          </div>
          <div className="flex shrink-0 items-center gap-2">
            <Button
              variant="outline"
              size="sm"
              onClick={() => setAll("present")}
              className="h-9 border-slate-200/80 text-xs font-semibold text-slate-600 hover:bg-slate-50 hover:text-slate-900"
            >
              Mark all present
            </Button>
          </div>
        </div>

        {/* Quick legend */}
        <div className="mt-6 flex flex-wrap items-center gap-3 text-xs text-slate-500">
          <span className="flex items-center gap-1.5">
            <span className="inline-block size-3 rounded-md border border-emerald-200 bg-emerald-50" />
            Present
          </span>
          <span className="flex items-center gap-1.5">
            <span className="inline-block size-3 rounded-md border border-red-200 bg-red-50" />
            Absent
          </span>
          <span className="flex items-center gap-1.5">
            <span className="inline-block size-3 rounded-md border border-amber-200 bg-amber-50" />
            Late
          </span>
          <span className="flex items-center gap-1.5">
            <span className="inline-block size-3 rounded-md border border-blue-200 bg-blue-50" />
            Excused
          </span>
        </div>
      </div>

      {/* Student rows */}
      <div className="divide-y divide-slate-100">
        {students.map((s, idx) => (
          <div
            key={s.id}
            className="flex items-center gap-3 px-5 py-3 transition-colors hover:bg-slate-50/60"
          >
            <span className="flex size-9 shrink-0 items-center justify-center rounded-full bg-blue-50 text-xs font-semibold text-blue-700 ring-1 ring-blue-100">
              {initials(s.name)}
            </span>
            <span className="min-w-0 flex-1 truncate text-sm font-medium text-slate-900">
              {s.name}
            </span>
            <div className="flex gap-1.5" role="radiogroup" aria-label={`Attendance for ${s.name}`}>
              {OPTIONS.map((opt) => {
                const active = statuses[s.id] === opt.value;
                return (
                  <button
                    key={opt.value}
                    type="button"
                    aria-label={`${s.name}: ${opt.value}`}
                    aria-pressed={active}
                    onClick={() => setStatuses((p) => ({ ...p, [s.id]: opt.value }))}
                    className={cn(
                      "flex size-9 items-center justify-center rounded-xl border text-sm font-bold transition-all focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-1",
                      active
                        ? `${opt.active} ring-1 ${opt.ring}`
                        : "border-slate-200 bg-white text-slate-400 hover:border-slate-300 hover:bg-slate-50 hover:text-slate-600"
                    )}
                  >
                    {opt.label}
                  </button>
                );
              })}
            </div>
          </div>
        ))}
      </div>

      {/* Sticky save bar */}
      <div className="sticky bottom-0 flex flex-wrap items-center justify-between gap-3 border-t border-slate-100 bg-white/95 px-5 py-3 backdrop-blur-sm">
        <div className="flex flex-wrap items-center gap-x-4 gap-y-1 text-xs text-slate-500">
          <span>
            <span className="font-semibold text-emerald-700">{present}</span> present
          </span>
          <span>
            <span className="font-semibold text-red-700">{absent}</span> absent
          </span>
          {late > 0 && (
            <span>
              <span className="font-semibold text-amber-700">{late}</span> late
            </span>
          )}
          {excused > 0 && (
            <span>
              <span className="font-semibold text-blue-700">{excused}</span> excused
            </span>
          )}
          <span className="text-slate-400">
            {students.length} total
          </span>
        </div>
        <Button
          onClick={save}
          disabled={isPending}
          className="gap-2 bg-[#10203f] text-white hover:bg-[#1b2d5e]"
        >
          {isPending ? (
            <Loader2 className="size-4 animate-spin" />
          ) : (
            <Check className="size-4" />
          )}
          Save attendance
        </Button>
      </div>
    </div>
  );
}
