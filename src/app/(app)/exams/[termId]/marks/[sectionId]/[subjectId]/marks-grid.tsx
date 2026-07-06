"use client";

import { useMemo, useState, useTransition } from "react";
import { toast } from "sonner";
import { Check, Loader2, Eye } from "lucide-react";
import { saveMarks } from "@/lib/actions/exams";
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  CardDescription,
} from "@/components/ui/card";
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
    <Card className="overflow-hidden border-0 shadow-md shadow-muted-foreground/5 ring-1 ring-border/50">
      <CardHeader className="gap-1">
        <CardTitle className="text-base">{title}</CardTitle>
        <CardDescription>
          {subtitle} · out of {maxMarks}
          {isPublished && (
            <span className="ml-2 inline-flex items-center gap-1 text-amber-600">
              <Eye className="size-3.5" /> published — edits update parents&apos; view
            </span>
          )}
        </CardDescription>
      </CardHeader>
      <CardContent className="p-0">
        <div className="overflow-x-auto">
          <div className="min-w-[420px] divide-y divide-border/60">
            <div className="flex items-center gap-3 px-5 py-2 text-xs font-semibold tracking-wide text-muted-foreground uppercase">
              <span className="flex-1">Student</span>
              <span className="w-24 text-center">Marks</span>
              <span className="w-14 text-center">Grade</span>
            </div>
            {students.map((s, i) => {
              const { grade, invalid } = gradeFor(values[s.id]);
              return (
                <div key={s.id} className="flex items-center gap-3 px-5 py-2.5">
                  <span className="flex size-8 shrink-0 items-center justify-center rounded-full bg-secondary text-xs font-medium text-secondary-foreground">
                    {initials(s.name)}
                  </span>
                  <label htmlFor={`mark-${s.id}`} className="min-w-0 flex-1 cursor-text truncate text-sm font-medium">
                    {s.name}
                    {s.roll ? <span className="ml-1.5 text-xs text-muted-foreground">#{s.roll}</span> : null}
                  </label>
                  <div className="w-24">
                    <div className="flex items-center gap-1">
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
                          "h-9 w-16 rounded-lg border bg-background px-2 text-right text-sm tabular-nums transition-colors outline-none focus-visible:ring-2 focus-visible:ring-ring/50",
                          invalid
                            ? "border-destructive text-destructive focus-visible:ring-destructive/40"
                            : "border-input focus-visible:border-ring"
                        )}
                      />
                      <span className="text-xs text-muted-foreground">/{maxMarks}</span>
                    </div>
                  </div>
                  <div className="flex w-14 justify-center">
                    {invalid ? (
                      <span className="text-xs font-medium text-destructive">&gt; max</span>
                    ) : grade ? (
                      <Badge variant="secondary" className="px-2 py-0.5 text-xs">
                        {grade}
                      </Badge>
                    ) : (
                      <span className="text-xs text-muted-foreground/50">—</span>
                    )}
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      </CardContent>

      <div className="sticky bottom-0 flex items-center justify-between gap-3 border-t border-border bg-card/95 px-6 py-3 backdrop-blur">
        <p className="text-sm text-muted-foreground">
          <span className="font-semibold text-foreground">{stats.entered}</span>/{students.length} entered
          {stats.avg !== null && (
            <>
              {" · avg "}
              <span className="font-semibold text-foreground tabular-nums">
                {stats.avg.toFixed(1)}
              </span>
            </>
          )}
        </p>
        <Button onClick={save} disabled={isPending || stats.anyInvalid} className="gap-2">
          {isPending ? <Loader2 className="size-4 animate-spin" /> : <Check className="size-4" />}
          Save marks
        </Button>
      </div>
    </Card>
  );
}
