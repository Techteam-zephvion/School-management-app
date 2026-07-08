"use client";

import { useMemo, useState, useTransition } from "react";
import { toast } from "sonner";
import { Check, Loader2, Eye } from "lucide-react";
import { saveMarks } from "@/lib/actions/exams";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { cn } from "@/lib/utils";

type Student = { id: string; name: string; roll: string | null; value: number | null };
type Band = { min: number; label: string };

function initials(name: string) {
  return name.split(/\s+/).map((p) => p[0]).slice(0, 2).join("").toUpperCase() || "?";
}

export function MarksGrid({
  termId,
  examSubjectId,
  maxMarks,
  title,
  subtitle,
  isPublished,
  gradeBands,
  students,
}: {
  termId: string;
  examSubjectId: string;
  maxMarks: number;
  title: string;
  subtitle: string;
  isPublished: boolean;
  gradeBands: Band[];
  students: Student[];
}) {
  const [values, setValues] = useState<Record<string, string>>(() =>
    Object.fromEntries(students.map((s) => [s.id, s.value === null ? "" : String(s.value)]))
  );
  const [isPending, startTransition] = useTransition();

  function gradeFor(raw: string): { grade: string | null; invalid: boolean } {
    if (raw.trim() === "") return { grade: null, invalid: false };
    const n = Number(raw);
    if (Number.isNaN(n) || n < 0 || n > maxMarks) return { grade: null, invalid: true };
    const pct = (n / maxMarks) * 100;
    const band = gradeBands.find((b) => pct >= b.min);
    return { grade: band?.label ?? null, invalid: false };
  }

  const stats = useMemo(() => {
    const nums = students
      .map((s) => values[s.id])
      .filter((v) => v.trim() !== "" && !Number.isNaN(Number(v)) && Number(v) >= 0 && Number(v) <= maxMarks)
      .map(Number);
    const anyInvalid = students.some((s) => gradeFor(values[s.id]).invalid);
    const avg = nums.length ? nums.reduce((a, b) => a + b, 0) / nums.length : null;
    return { entered: nums.length, avg, anyInvalid };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [values, students, maxMarks]);

  function focusRow(index: number) {
    const el = document.querySelector<HTMLInputElement>(`input[data-row="${index}"]`);
    el?.focus();
    el?.select();
  }

  function save() {
    if (stats.anyInvalid) {
      toast.error(`Marks must be between 0 and ${maxMarks}.`);
      return;
    }
    startTransition(async () => {
      const result = await saveMarks({
        termId,
        examSubjectId,
        marks: students.map((s) => {
          const raw = values[s.id].trim();
          return { studentId: s.id, value: raw === "" ? null : Number(raw) };
        }),
      });
      if (result?.error) toast.error(result.error);
      else toast.success("Marks saved.");
    });
  }

  return (
    <div className="overflow-hidden rounded-2xl border border-slate-200/80 bg-white/95 shadow-sm shadow-slate-950/5 ring-1 ring-slate-900/[0.02]">
      {/* Header */}
      <div className="border-b border-slate-100 px-5 py-4">
        <div className="flex items-start justify-between gap-3">
          <div className="flex min-w-0 items-start gap-3">
            <span className="flex size-10 shrink-0 items-center justify-center rounded-2xl bg-blue-50 text-blue-700 ring-1 ring-blue-100">
              <Check className="size-5" />
            </span>
            <div className="min-w-0">
              <p className="text-xs font-semibold uppercase tracking-wide text-slate-500">
                Mark entry
              </p>
              <h3 className="mt-0.5 truncate text-base font-semibold text-slate-900">{title}</h3>
              <p className="mt-0.5 text-xs text-slate-500">
                {subtitle} · out of {maxMarks}
                {isPublished && (
                  <span className="ml-2 inline-flex items-center gap-1 text-amber-600">
                    <Eye className="size-3.5" /> published — edits update parents&apos; view
                  </span>
                )}
              </p>
            </div>
          </div>
        </div>
        {/* Column labels */}
        <div className="mt-3 flex items-center gap-3 text-xs font-semibold uppercase tracking-wide text-slate-400">
          <span className="flex-1 pl-12">Student</span>
          <span className="w-28 text-center">Marks</span>
          <span className="w-16 text-center">Grade</span>
        </div>
      </div>

      {/* Student rows */}
      <div className="divide-y divide-slate-100">
        {students.map((s, i) => {
          const { grade, invalid } = gradeFor(values[s.id]);
          return (
            <div
              key={s.id}
              className="flex items-center gap-3 px-5 py-2.5 transition-colors hover:bg-slate-50/60"
            >
              <span className="flex size-9 shrink-0 items-center justify-center rounded-full bg-blue-50 text-xs font-semibold text-blue-700 ring-1 ring-blue-100">
                {initials(s.name)}
              </span>
              <label
                htmlFor={`mark-${s.id}`}
                className="min-w-0 flex-1 cursor-text truncate text-sm font-medium text-slate-900"
              >
                {s.name}
                {s.roll ? (
                  <span className="ml-1.5 text-xs text-slate-400">#{s.roll}</span>
                ) : null}
              </label>
              <div className="flex w-28 items-center justify-center gap-1">
                <input
                  id={`mark-${s.id}`}
                  data-row={i}
                  type="number"
                  inputMode="decimal"
                  min={0}
                  max={maxMarks}
                  step="any"
                  aria-label={`Marks for ${s.name}, out of ${maxMarks}`}
                  aria-invalid={invalid}
                  value={values[s.id]}
                  onChange={(e) => setValues((p) => ({ ...p, [s.id]: e.target.value }))}
                  onKeyDown={(e) => {
                    if (e.key === "Enter") {
                      e.preventDefault();
                      focusRow(i + 1);
                    }
                  }}
                  className={cn(
                    "h-9 w-16 rounded-xl border bg-white px-2 text-right text-sm tabular-nums outline-none transition-colors focus-visible:ring-2 focus-visible:ring-ring",
                    invalid
                      ? "border-red-300 text-red-600 focus-visible:ring-red-400/50"
                      : "border-slate-200 focus-visible:border-blue-300 focus-visible:ring-blue-500"
                  )}
                />
                <span className="text-xs text-slate-400">/{maxMarks}</span>
              </div>
              <div className="flex w-16 items-center justify-center">
                {invalid ? (
                  <span className="text-xs font-medium text-red-600">&gt; max</span>
                ) : grade ? (
                  <Badge
                    variant="secondary"
                    className="border-slate-200 bg-slate-50 px-2 py-0.5 text-xs font-medium text-slate-700"
                  >
                    {grade}
                  </Badge>
                ) : (
                  <span className="text-xs text-slate-300">—</span>
                )}
              </div>
            </div>
          );
        })}
      </div>

      {/* Sticky save bar */}
      <div className="sticky bottom-0 flex flex-wrap items-center justify-between gap-3 border-t border-slate-100 bg-white/95 px-5 py-3 backdrop-blur-sm">
        <p className="text-xs text-slate-500">
          <span className="font-semibold text-slate-900">{stats.entered}</span>/{students.length} entered
          {stats.avg !== null && (
            <>
              {" · avg "}
              <span className="font-semibold text-slate-900 tabular-nums">
                {stats.avg.toFixed(1)}
              </span>
            </>
          )}
        </p>
        <Button
          onClick={save}
          disabled={isPending || stats.anyInvalid}
          className="gap-2 bg-[#10203f] text-white hover:bg-[#1b2d5e]"
        >
          {isPending ? (
            <Loader2 className="size-4 animate-spin" />
          ) : (
            <Check className="size-4" />
          )}
          Save marks
        </Button>
      </div>
    </div>
  );
}
