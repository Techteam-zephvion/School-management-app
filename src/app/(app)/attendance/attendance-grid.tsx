"use client";

import { useState, useTransition } from "react";
import { toast } from "sonner";
import { Check, Loader2 } from "lucide-react";
import { saveAttendance, type AttendStatus } from "@/lib/actions/attendance";
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  CardDescription,
} from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";

type Student = { id: string; name: string; status: AttendStatus | null };

const OPTIONS: { value: AttendStatus; label: string; active: string }[] = [
  { value: "present", label: "P", active: "bg-success text-success-foreground border-success" },
  { value: "absent", label: "A", active: "bg-destructive text-white border-destructive" },
  { value: "late", label: "L", active: "bg-warning text-warning-foreground border-warning" },
  { value: "excused", label: "E", active: "bg-accent text-accent-foreground border-accent" },
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
    <Card>
      <CardHeader className="flex-row items-start justify-between gap-3 space-y-0">
        <div>
          <CardTitle className="text-base">{label}</CardTitle>
          <CardDescription>
            {new Date(date + "T00:00:00").toLocaleDateString("en-IN", {
              weekday: "long",
              day: "numeric",
              month: "long",
            })}
            {alreadyMarked ? " · already marked (editing)" : ""}
          </CardDescription>
        </div>
        <Button variant="outline" size="sm" onClick={() => setAll("present")}>
          Mark all present
        </Button>
      </CardHeader>
      <CardContent className="space-y-1">
        {students.map((s) => (
          <div
            key={s.id}
            className="flex items-center gap-3 rounded-lg px-1 py-1.5"
          >
            <span className="flex size-8 shrink-0 items-center justify-center rounded-full bg-secondary text-xs font-medium text-secondary-foreground">
              {initials(s.name)}
            </span>
            <span className="min-w-0 flex-1 truncate text-sm font-medium">{s.name}</span>
            <div className="flex gap-1">
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
                      "flex size-8 items-center justify-center rounded-md border text-sm font-semibold transition-colors",
                      active
                        ? opt.active
                        : "border-border bg-background text-muted-foreground hover:bg-muted"
                    )}
                  >
                    {opt.label}
                  </button>
                );
              })}
            </div>
          </div>
        ))}
      </CardContent>

      {/* sticky save bar */}
      <div className="sticky bottom-0 flex items-center justify-between gap-3 border-t border-border bg-card/95 px-6 py-3 backdrop-blur">
        <p className="text-sm text-muted-foreground">
          <span className="font-semibold text-foreground">{present}</span> present ·{" "}
          <span className="font-semibold text-foreground">{absent}</span> absent ·{" "}
          {students.length} total
        </p>
        <Button onClick={save} disabled={isPending} className="gap-2">
          {isPending ? <Loader2 className="size-4 animate-spin" /> : <Check className="size-4" />}
          Save attendance
        </Button>
      </div>
    </Card>
  );
}
