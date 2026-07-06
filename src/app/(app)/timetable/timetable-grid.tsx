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

export function TimetableGrid({
  sectionId,
  periods,
  subjects,
  staff,
  canEdit,
}: {
  sectionId: string;
  periods: PeriodCell[];
  subjects: Option[];
  staff: Option[];
  canEdit: boolean;
}) {
  const [isPending, startTransition] = useTransition();
  const [dialog, setDialog] = useState<{ weekday: number; periodNo: number } | null>(null);
  const [subjectId, setSubjectId] = useState("");
  const [staffId, setStaffId] = useState("");

  const maxPeriod = Math.max(6, ...periods.map((p) => p.periodNo));
  const rows = Array.from({ length: maxPeriod }, (_, i) => i + 1);
  const cellOf = (weekday: number, periodNo: number) =>
    periods.find((p) => p.weekday === weekday && p.periodNo === periodNo);

  const [state, formAction, saving] = useActionState(
    async (prev: Awaited<ReturnType<typeof addPeriod>>, fd: FormData) => {
      if (!dialog) return prev;
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
    setSubjectId(existing?.subjectId ?? "");
    setStaffId("");
    setDialog({ weekday, periodNo });
  }

  return (
    <Card className="overflow-hidden border-0 shadow-md shadow-muted-foreground/5 ring-1 ring-border/50">
      <CardHeader>
        <CardTitle className="text-base">Weekly schedule</CardTitle>
        <CardDescription>
          {canEdit ? "Tap a cell to assign a subject and teacher." : "Read-only. Ask your admin to edit."}
        </CardDescription>
      </CardHeader>
      <CardContent className="p-0">
        <div className="overflow-x-auto">
          <table className="w-full min-w-[640px] border-separate border-spacing-0 text-sm">
            <thead>
              <tr>
                <th className="sticky left-0 z-10 w-14 bg-card px-3 py-2 text-left text-xs font-semibold text-muted-foreground">
                  #
                </th>
                {DAYS.map((d) => (
                  <th key={d} className="px-2 py-2 text-center text-xs font-semibold text-muted-foreground">
                    {d}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {rows.map((periodNo) => (
                <tr key={periodNo}>
                  <td className="sticky left-0 z-10 border-t border-border/60 bg-card px-3 py-2 text-xs font-medium text-muted-foreground">
                    {periodNo}
                  </td>
                  {DAYS.map((_, weekday) => {
                    const cell = cellOf(weekday, periodNo);
                    return (
                      <td key={weekday} className="border-t border-l border-border/60 p-1 align-top">
                        {cell ? (
                          <div className="group relative rounded-lg bg-primary/5 px-2 py-1.5">
                            <p className="truncate text-xs font-semibold text-foreground">{cell.subjectName}</p>
                            {cell.staffName && (
                              <p className="truncate text-[11px] text-muted-foreground">{cell.staffName}</p>
                            )}
                            {canEdit && (
                              <button
                                type="button"
                                disabled={isPending}
                                onClick={() => remove(cell.id)}
                                aria-label="Remove period"
                                className="absolute top-0.5 right-0.5 hidden size-4 items-center justify-center rounded text-muted-foreground group-hover:flex hover:bg-destructive/10 hover:text-destructive"
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
                            className="flex h-11 w-full items-center justify-center rounded-lg text-muted-foreground/40 transition-colors hover:bg-muted/60 hover:text-muted-foreground"
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
              <Label className="text-sm font-medium text-foreground">Subject</Label>
              <Select value={subjectId} onValueChange={setSubjectId}>
                <SelectTrigger className="w-full rounded-lg">
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
              <Label className="text-sm font-medium text-foreground">Teacher (optional)</Label>
              <Select value={staffId} onValueChange={setStaffId}>
                <SelectTrigger className="w-full rounded-lg">
                  <SelectValue placeholder="Unassigned" />
                </SelectTrigger>
                <SelectContent>
                  {staff.map((s) => (
                    <SelectItem key={s.id} value={s.id}>
                      {s.name}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <div className="grid grid-cols-2 gap-4">
              <div className="space-y-2">
                <Label htmlFor="startTime" className="text-sm font-medium text-foreground">Start (optional)</Label>
                <Input id="startTime" name="startTime" type="time" className="rounded-lg" />
              </div>
              <div className="space-y-2">
                <Label htmlFor="endTime" className="text-sm font-medium text-foreground">End (optional)</Label>
                <Input id="endTime" name="endTime" type="time" className="rounded-lg" />
              </div>
            </div>
            {state?.error && <p className="text-sm text-destructive">{state.error}</p>}
            <DialogFooter>
              <Button type="submit" disabled={saving || !subjectId} className={cn("gap-2")}>
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
