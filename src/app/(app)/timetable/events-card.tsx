"use client";

import { useActionState, useState, useTransition } from "react";
import { toast } from "sonner";
import { CalendarDays, PartyPopper, Plane, X, Loader2, Plus } from "lucide-react";
import { addEvent, deleteEvent } from "@/lib/actions/timetable";
import type { SectionOption } from "./page";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Badge } from "@/components/ui/badge";
import { Checkbox } from "@/components/ui/checkbox";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
  DialogFooter,
} from "@/components/ui/dialog";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";

type EventRow = {
  id: string;
  title: string;
  description: string | null;
  startDate: string;
  endDate: string;
  isHoliday: boolean;
  scope: string;
};

const ALL = "__all__";
function fmt(d: string) {
  return new Date(d + "T00:00:00").toLocaleDateString("en-IN", { day: "2-digit", month: "short" });
}

export function EventsCard({
  events,
  sections,
  canEdit,
}: {
  events: EventRow[];
  sections: SectionOption[];
  canEdit: boolean;
}) {
  const [open, setOpen] = useState(false);
  const [sectionId, setSectionId] = useState(ALL);
  const [isPending, startTransition] = useTransition();

  const [state, formAction, saving] = useActionState(
    async (prev: Awaited<ReturnType<typeof addEvent>>, fd: FormData) => {
      fd.set("sectionId", sectionId === ALL ? "" : sectionId);
      const result = await addEvent(prev, fd);
      if (!result?.error) {
        toast.success("Event added.");
        setOpen(false);
        setSectionId(ALL);
      }
      return result;
    },
    undefined
  );

  function remove(id: string) {
    startTransition(async () => {
      const result = await deleteEvent(id);
      if (result?.error) toast.error(result.error);
    });
  }

  return (
    <Card className="overflow-hidden border-0 bg-white shadow-sm shadow-slate-950/5 ring-1 ring-slate-900/[0.02]">
      <CardHeader className="flex-row items-start justify-between space-y-0">
        <div>
          <CardTitle className="text-base text-slate-900">Holidays &amp; events</CardTitle>
          <CardDescription>Holidays block attendance marking on those dates.</CardDescription>
        </div>
        {canEdit && (
          <Dialog open={open} onOpenChange={setOpen}>
            <DialogTrigger asChild>
              <Button variant="outline" className="gap-2 border-slate-200/80 text-slate-700 hover:bg-slate-50 hover:text-slate-900">
                <Plus className="size-4" /> Add event
              </Button>
            </DialogTrigger>
            <DialogContent>
              <DialogHeader>
                <DialogTitle>Add holiday or event</DialogTitle>
              </DialogHeader>
              <form action={formAction} className="space-y-4">
                <div className="space-y-2">
                  <Label htmlFor="title" className="text-xs font-semibold uppercase tracking-wide text-slate-600">Title</Label>
                  <Input id="title" name="title" placeholder="Independence Day" required className="rounded-xl border-slate-200/80 bg-white shadow-sm focus:border-blue-400 focus:ring-2 focus:ring-blue-100" />
                </div>
                <div className="grid grid-cols-2 gap-4">
                  <div className="space-y-2">
                    <Label htmlFor="startDate" className="text-xs font-semibold uppercase tracking-wide text-slate-600">From</Label>
                    <Input id="startDate" name="startDate" type="date" required className="rounded-xl border-slate-200/80 bg-white shadow-sm focus:border-blue-400 focus:ring-2 focus:ring-blue-100" />
                  </div>
                  <div className="space-y-2">
                    <Label htmlFor="endDate" className="text-xs font-semibold uppercase tracking-wide text-slate-600">To</Label>
                    <Input id="endDate" name="endDate" type="date" required className="rounded-xl border-slate-200/80 bg-white shadow-sm focus:border-blue-400 focus:ring-2 focus:ring-blue-100" />
                  </div>
                </div>
                <div className="space-y-2">
                  <Label className="text-xs font-semibold uppercase tracking-wide text-slate-600">Applies to</Label>
                  <Select value={sectionId} onValueChange={setSectionId}>
                    <SelectTrigger className="w-full rounded-xl border-slate-200/80 bg-white shadow-sm focus:border-blue-400 focus:ring-2 focus:ring-blue-100">
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value={ALL}>Whole school</SelectItem>
                      {sections.map((s) => (
                        <SelectItem key={s.id} value={s.id}>
                          {s.name}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
                <label className="flex items-center gap-2.5 rounded-xl border border-slate-200/80 bg-white p-3 shadow-sm">
                  <Checkbox id="isHoliday" name="isHoliday" defaultChecked />
                  <span className="text-sm">
                    <span className="font-medium text-slate-900">This is a holiday</span>
                    <span className="block text-xs text-slate-500">Attendance can&apos;t be marked on these dates.</span>
                  </span>
                </label>
                {state?.error && (
                  <div className="flex items-start gap-2.5 rounded-xl border border-red-200/60 bg-red-50/60 p-3">
                    <p className="text-xs font-medium text-red-700">{state.error}</p>
                  </div>
                )}
                <DialogFooter>
                  <Button type="submit" disabled={saving} className="gap-2 bg-[#10203f] text-white hover:bg-[#1b2d5e]">
                    {saving && <Loader2 className="size-4 animate-spin" />}
                    Add event
                  </Button>
                </DialogFooter>
              </form>
            </DialogContent>
          </Dialog>
        )}
      </CardHeader>
      <CardContent className="divide-y divide-slate-100 p-0">
        {events.length === 0 ? (
          <div className="flex flex-col items-center gap-3 py-10 text-center">
            <span className="flex size-12 items-center justify-center rounded-2xl bg-blue-50 text-blue-700 ring-1 ring-blue-100">
              <CalendarDays className="size-6" />
            </span>
            <div>
              <p className="text-sm font-medium text-slate-700">No events yet</p>
              <p className="mt-0.5 text-xs text-slate-500">Add holidays so attendance is blocked on those days.</p>
            </div>
          </div>
        ) : (
          events.map((e) => (
            <div key={e.id} className="flex items-center gap-3 px-5 py-3">
              <span
                className={`flex size-9 shrink-0 items-center justify-center rounded-xl ${
                  e.isHoliday
                    ? "bg-amber-50 text-amber-700 ring-1 ring-amber-200"
                    : "bg-blue-50 text-blue-700 ring-1 ring-blue-100"
                }`}
              >
                {e.isHoliday ? <Plane className="size-4" /> : <PartyPopper className="size-4" />}
              </span>
              <div className="min-w-0 flex-1">
                <p className="flex items-center gap-2 truncate text-sm font-semibold text-slate-900">
                  {e.title}
                  {e.isHoliday && <Badge variant="warning" className="px-2 py-0 text-[11px]">Holiday</Badge>}
                </p>
                <p className="truncate text-xs text-slate-500">
                  {fmt(e.startDate)}{e.endDate !== e.startDate ? ` – ${fmt(e.endDate)}` : ""} · {e.scope}
                </p>
              </div>
              {canEdit && (
                <button
                  type="button"
                  disabled={isPending}
                  onClick={() => remove(e.id)}
                  aria-label={`Remove ${e.title}`}
                  className="flex size-7 items-center justify-center rounded-lg text-slate-400 transition-colors hover:bg-red-50 hover:text-red-600"
                >
                  <X className="size-4" />
                </button>
              )}
            </div>
          ))
        )}
      </CardContent>
    </Card>
  );
}

