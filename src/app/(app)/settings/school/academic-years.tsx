"use client";

import { useActionState, useState, useTransition } from "react";
import { toast } from "sonner";
import { CalendarPlus, CheckCircle2, Calendar } from "lucide-react";
import { createAcademicYear, setActiveAcademicYear } from "@/lib/actions/academic";
import type { Tables } from "@/lib/supabase/database.types";
import { Card, CardContent } from "@/components/ui/card";
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
  DialogDescription,
  DialogTrigger,
  DialogFooter,
} from "@/components/ui/dialog";

function fmt(d: string) {
  return new Date(d).toLocaleDateString("en-IN", {
    day: "2-digit",
    month: "short",
    year: "numeric",
  });
}

export function AcademicYears({ years }: { years: Tables<"academic_years">[] }) {
  const [open, setOpen] = useState(false);
  const [isPending, startTransition] = useTransition();

  const [state, formAction, pending] = useActionState(
    async (prev: Awaited<ReturnType<typeof createAcademicYear>>, fd: FormData) => {
      const result = await createAcademicYear(prev, fd);
      if (!result?.error) {
        toast.success("Academic year added.");
        setOpen(false);
      }
      return result;
    },
    undefined
  );

  function activate(id: string) {
    startTransition(async () => {
      const result = await setActiveAcademicYear(id);
      if (result?.error) toast.error(result.error);
      else toast.success("Active academic year updated.");
    });
  }

  return (
    <Card className="overflow-hidden border border-slate-200/80 bg-white shadow-sm shadow-slate-950/5 ring-1 ring-slate-900/[0.02]">
      {/* Card header */}
      <div className="flex flex-wrap items-start justify-between gap-3 border-b border-slate-100 px-5 py-4">
        <div className="flex items-center gap-3">
          <span className="flex size-9 items-center justify-center rounded-xl bg-blue-50 text-blue-700 ring-1 ring-blue-100">
            <Calendar className="size-4.5" />
          </span>
          <div>
            <h2 className="text-base font-semibold text-slate-900">Academic years</h2>
            <p className="text-xs text-slate-500">Exactly one year is active at a time.</p>
          </div>
        </div>
        <Dialog open={open} onOpenChange={setOpen}>
          <DialogTrigger asChild>
            <Button className="gap-2 bg-primary text-primary-foreground hover:bg-primary/80">
              <CalendarPlus className="size-4" /> Add year
            </Button>
          </DialogTrigger>
          <DialogContent className="sm:max-w-lg">
            <DialogHeader>
              <div className="flex items-center gap-3">
                <span className="flex size-9 shrink-0 items-center justify-center rounded-xl bg-blue-50 text-blue-700 ring-1 ring-blue-100">
                  <Calendar className="size-4.5" />
                </span>
                <div>
                  <DialogTitle>Add an academic year</DialogTitle>
                  <DialogDescription>
                    e.g. &ldquo;2025-26&rdquo;, running June to April.
                  </DialogDescription>
                </div>
              </div>
            </DialogHeader>
            <form action={formAction} className="space-y-5">
              <div className="space-y-2">
                <Label htmlFor="year-name" className="text-xs font-semibold text-slate-600">Name</Label>
                <Input id="year-name" name="name" placeholder="2025-26" required />
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-2">
                  <Label htmlFor="startDate" className="text-xs font-semibold text-slate-600">Start date</Label>
                  <Input id="startDate" name="startDate" type="date" required />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="endDate" className="text-xs font-semibold text-slate-600">End date</Label>
                  <Input id="endDate" name="endDate" type="date" required />
                </div>
              </div>
              <div className="flex items-center gap-2">
                <Checkbox id="isActive" name="isActive" defaultChecked />
                <Label htmlFor="isActive" className="text-sm font-normal text-slate-600">
                  Make this the active year
                </Label>
              </div>
              {state?.error && (
                <div className="rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
                  {state.error}
                </div>
              )}
              <DialogFooter className="gap-2 sm:gap-0">
                <Button type="submit" disabled={pending} className="gap-2 bg-primary text-primary-foreground hover:bg-primary/80">
                  {pending ? "Adding…" : "Add year"}
                </Button>
              </DialogFooter>
            </form>
          </DialogContent>
        </Dialog>
      </div>

      <CardContent className="divide-y divide-slate-100 p-0">
        {years.length === 0 ? (
          <div className="flex flex-col items-center gap-4 px-5 py-10 text-center">
            <span className="flex size-12 items-center justify-center rounded-2xl bg-slate-50 text-slate-400 ring-1 ring-slate-200">
              <Calendar className="size-5" />
            </span>
            <div>
              <p className="text-sm font-medium text-slate-700">No academic years yet</p>
              <p className="mt-0.5 text-xs text-slate-500">Add one to start creating sections.</p>
            </div>
          </div>
        ) : (
          years.map((y) => (
            <div
              key={y.id}
              className="group flex items-center gap-4 px-5 py-4 transition-colors hover:bg-blue-50/50"
            >
              <span className="flex size-10 shrink-0 items-center justify-center rounded-2xl bg-blue-50 text-blue-700 ring-1 ring-blue-100">
                <Calendar className="size-5" />
              </span>
              <div className="min-w-0 flex-1">
                <p className="truncate text-sm font-semibold text-slate-900">{y.name}</p>
                <p className="truncate text-xs text-slate-500">
                  {fmt(y.start_date)} – {fmt(y.end_date)}
                </p>
              </div>
              {y.is_active ? (
                <Badge variant="success" className="gap-1 shrink-0">
                  <CheckCircle2 className="size-3" /> Active
                </Badge>
              ) : (
                <Button
                  variant="outline"
                  size="sm"
                  disabled={isPending}
                  onClick={() => activate(y.id)}
                >
                  Make active
                </Button>
              )}
            </div>
          ))
        )}
      </CardContent>
    </Card>
  );
}
