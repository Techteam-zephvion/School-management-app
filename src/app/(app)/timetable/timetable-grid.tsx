"use client";

import { useActionState, useState, useTransition } from "react";
import { toast } from "sonner";
import { Plus, X, Loader2, CalendarClock } from "lucide-react";
import { addPeriod, deletePeriod } from "@/lib/actions/timetable";
import type { Option, PeriodCell } from "./page";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogFooter,
} from "@/components/ui/dialog";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { cn } from "@/lib/utils";

const DAYS = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];

/** DB times come back as "HH:MM:SS"; <input type=time> and the UI want "HH:MM". */
function toInput(t: string | null): string {
  if (!t) return "";
  const [h, m] = t.split(":");
  return `${h.padStart(2, "0")}:${m.padStart(2, "0")}`;
}
function toMin(t: string): number {
  const [h, m] = t.split(":");
  return Number(h) * 60 + Number(m);
}

export function TimetableGrid({
  sectionId,
  periods,
  subjects,
  teachersBySubject,
  canEdit,
}: {
  sectionId: string;
  periods: PeriodCell[];
  subjects: Option[];
  teachersBySubject: Record<string, Option[]>;
  canEdit: boolean;
}) {
  const [isPending, startTransition] = useTransition();
  const [dialog, setDialog] = useState<{ weekday: number; periodNo: number } | null>(null);
  const [subjectId, setSubjectId] = useState("");
  const [staffId, setStaffId] = useState("");
  const [startTime, setStartTime] = useState("");
  const [endTime, setEndTime] = useState("");
  const [extraRows, setExtraRows] = useState(0);

  const baseRows = Math.max(6, ...periods.map((p) => p.periodNo));
  const totalRows = Math.min(12, baseRows + extraRows);
  const rows = Array.from({ length: totalRows }, (_, i) => i + 1);

  // Teachers that may take the currently chosen subject in this section (Roles).
  const teacherChoices = subjectId ? teachersBySubject[subjectId] ?? [] : [];

  function pickSubject(id: string) {
    setSubjectId(id);
    const choices = teachersBySubject[id] ?? [];
    // auto-assign when exactly one teacher is assigned; otherwise clear
    setStaffId(choices.length === 1 ? choices[0].id : "");
  }
  const cellOf = (weekday: number, periodNo: number) =>
    periods.find((p) => p.weekday === weekday && p.periodNo === periodNo);

  const [state, formAction, saving] = useActionState(
    async (prev: Awaited<ReturnType<typeof addPeriod>>, fd: FormData) => {
      if (!dialog) return prev;
      // Instant feedback before hitting the server (which re-validates).
      if (!startTime || !endTime) return { error: "Set the period's start and end time." };
      if (toMin(endTime) <= toMin(startTime)) return { error: "The end time must be after the start time." };
      const clash = periods.find(
        (p) =>
          p.weekday === dialog.weekday &&
          p.periodNo !== dialog.periodNo &&
          p.startTime &&
          p.endTime &&
          toMin(startTime) < toMin(p.endTime) &&
          toMin(p.startTime) < toMin(endTime)
      );
      if (clash) {
        return {
          error: `These timings clash with period ${clash.periodNo} (${toInput(clash.startTime)}–${toInput(clash.endTime)}). Periods on the same day can't overlap.`,
        };
      }

      fd.set("sectionId", sectionId);
      fd.set("weekday", String(dialog.weekday));
      fd.set("periodNo", String(dialog.periodNo));
      fd.set("subjectId", subjectId);
      fd.set("staffId", staffId);
      const result = await addPeriod(prev, fd);
      if (!result?.error) {
        toast.success("Period saved.");
        setDialog(null);
        setSubjectId("");
        setStaffId("");
        setStartTime("");
        setEndTime("");
      }
      return result;
    },
    undefined
  );

  function remove(id: string) {
    startTransition(async () => {
      const result = await deletePeriod(id);
      if (result?.error) toast.error(result.error);
    });
  }

  function openAdd(weekday: number, periodNo: number) {
    const existing = cellOf(weekday, periodNo);
    pickSubject(existing?.subjectId ?? "");

    // Prefill timings so periods chain without collisions: use this cell's own
    // times if editing, else keep the period consistent with the same period on
    // another day, else start right after the previous period ends.
    let start = existing?.startTime ?? "";
    let end = existing?.endTime ?? "";
    if (!start) {
      const sameNoOtherDay = periods.find((p) => p.periodNo === periodNo && p.startTime && p.endTime);
      const prev = cellOf(weekday, periodNo - 1);
      if (sameNoOtherDay) {
        start = sameNoOtherDay.startTime!;
        end = sameNoOtherDay.endTime!;
      } else if (prev?.endTime) {
        start = prev.endTime;
      }
    }
    setStartTime(toInput(start || null));
    setEndTime(toInput(end || null));
    setDialog({ weekday, periodNo });
  }

  return (
    <Card className="overflow-hidden border-0 bg-white shadow-sm shadow-slate-950/5 ring-1 ring-slate-900/[0.02]">
      <CardHeader>
        <CardTitle className="text-base text-slate-900">Weekly schedule</CardTitle>
        <CardDescription>
          {canEdit ? "Tap a cell to assign a subject and teacher." : "Read-only. Ask your admin to edit."}
        </CardDescription>
      </CardHeader>
      <CardContent className="p-0">
        <div className="overflow-x-auto">
          <table className="w-full min-w-[640px] border-separate border-spacing-0 text-sm">
            <thead>
              <tr>
                <th className="sticky left-0 z-10 w-14 bg-white px-3 py-2 text-left text-xs font-semibold text-slate-500">
                  #
                </th>
                {DAYS.map((d) => (
                  <th key={d} className="px-2 py-2 text-center text-xs font-semibold text-slate-500">
                    {d}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {rows.map((periodNo) => (
                <tr key={periodNo}>
                  <td className="sticky left-0 z-10 border-t border-slate-200/60 bg-white px-3 py-2 text-xs font-medium text-slate-500">
                    {periodNo}
                  </td>
                  {DAYS.map((_, weekday) => {
                    const cell = cellOf(weekday, periodNo);
                    return (
                      <td key={weekday} className="border-t border-l border-slate-200/60 p-1 align-top">
                        {cell ? (
                          <div className="group relative rounded-lg bg-blue-50/60 px-2 py-1.5 ring-1 ring-blue-100/50">
                            {cell.startTime && cell.endTime && (
                              <p className="truncate text-[10px] font-medium text-blue-600/70 tabular-nums">
                                {toInput(cell.startTime)}–{toInput(cell.endTime)}
                              </p>
                            )}
                            <p className="truncate text-xs font-semibold text-slate-900">{cell.subjectName}</p>
                            {cell.staffName && (
                              <p className="truncate text-[11px] text-slate-500">{cell.staffName}</p>
                            )}
                            {canEdit && (
                              <button
                                type="button"
                                disabled={isPending}
                                onClick={() => remove(cell.id)}
                                aria-label="Remove period"
                                className="absolute top-0.5 right-0.5 hidden size-4 items-center justify-center rounded text-slate-400 group-hover:flex hover:bg-red-50 hover:text-red-600"
                              >
                                <X className="size-3" />
                              </button>
                            )}
                          </div>
                        ) : canEdit ? (
                          <button
                            type="button"
                            onClick={() => openAdd(weekday, periodNo)}
                            aria-label={`Add ${DAYS[weekday]} period ${periodNo}`}
                            className="flex h-11 w-full items-center justify-center rounded-lg text-slate-300 transition-colors hover:bg-blue-50/60 hover:text-blue-500"
                          >
                            <Plus className="size-3.5" />
                          </button>
                        ) : (
                          <div className="h-11" />
                        )}
                      </td>
                    );
                  })}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        {canEdit && totalRows < 12 && (
          <div className="border-t border-slate-200/60 p-2">
            <Button
              variant="ghost"
              size="sm"
              onClick={() => setExtraRows((n) => n + 1)}
              className="w-full gap-1.5 text-slate-500 hover:text-blue-600 hover:bg-blue-50"
            >
              <Plus className="size-3.5" /> Add period row
            </Button>
          </div>
        )}
      </CardContent>

      <Dialog open={dialog !== null} onOpenChange={(o) => !o && setDialog(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>
              {dialog ? `${DAYS[dialog.weekday]} · Period ${dialog.periodNo}` : "Add period"}
            </DialogTitle>
          </DialogHeader>
          <form action={formAction} className="space-y-4">
            <div className="space-y-2">
              <Label className="text-xs font-semibold uppercase tracking-wide text-slate-600">Subject</Label>
              <Select value={subjectId} onValueChange={pickSubject}>
                <SelectTrigger className="w-full rounded-xl border-slate-200/80 bg-white shadow-sm focus:border-blue-400 focus:ring-2 focus:ring-blue-100">
                  <SelectValue placeholder={subjects.length === 0 ? "Map subjects to this class first" : "Choose subject"} />
                </SelectTrigger>
                <SelectContent>
                  {subjects.map((s) => (
                    <SelectItem key={s.id} value={s.id}>
                      {s.name}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <div className="space-y-2">
              <Label className="text-xs font-semibold uppercase tracking-wide text-slate-600">Teacher</Label>
              <Select value={staffId} onValueChange={setStaffId} disabled={!subjectId || teacherChoices.length === 0}>
                <SelectTrigger className="w-full rounded-xl border-slate-200/80 bg-white shadow-sm focus:border-blue-400 focus:ring-2 focus:ring-blue-100">
                  <SelectValue
                    placeholder={
                      !subjectId
                        ? "Choose a subject first"
                        : teacherChoices.length === 0
                          ? "No teacher assigned — set in Roles"
                          : "Choose teacher"
                    }
                  />
                </SelectTrigger>
                <SelectContent>
                  {teacherChoices.map((s) => (
                    <SelectItem key={s.id} value={s.id}>
                      {s.name}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
              {subjectId && teacherChoices.length === 0 && (
                <p className="text-xs text-slate-500">
                  Assign a subject teacher for this section in Roles to schedule them here.
                </p>
              )}
            </div>
            <div className="grid grid-cols-2 gap-4">
              <div className="space-y-2">
                <Label htmlFor="startTime" className="text-xs font-semibold uppercase tracking-wide text-slate-600">Starts</Label>
                <Input
                  id="startTime"
                  name="startTime"
                  type="time"
                  required
                  value={startTime}
                  onChange={(e) => setStartTime(e.target.value)}
                  className="rounded-xl border-slate-200/80 bg-white shadow-sm focus:border-blue-400 focus:ring-2 focus:ring-blue-100"
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="endTime" className="text-xs font-semibold uppercase tracking-wide text-slate-600">Ends</Label>
                <Input
                  id="endTime"
                  name="endTime"
                  type="time"
                  required
                  value={endTime}
                  onChange={(e) => setEndTime(e.target.value)}
                  className="rounded-xl border-slate-200/80 bg-white shadow-sm focus:border-blue-400 focus:ring-2 focus:ring-blue-100"
                />
              </div>
            </div>
            <p className="text-xs text-slate-500">
              The next period should start after the previous one ends — periods on the same day can&apos;t overlap.
            </p>
            {state?.error && <p className="text-sm text-red-600">{state.error}</p>}
            <DialogFooter>
              <Button type="submit" disabled={saving || !subjectId || !startTime || !endTime} className="gap-2 bg-[#10203f] text-white hover:bg-[#1b2d5e]">
                {saving && <Loader2 className="size-4 animate-spin" />}
                <CalendarClock className="size-4" /> Save period
              </Button>
            </DialogFooter>
          </form>
        </DialogContent>
      </Dialog>
    </Card>
  );
}
