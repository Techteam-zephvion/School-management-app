"use client";

import { useActionState, useState, useTransition } from "react";
import { toast } from "sonner";
import { CalendarPlus, CheckCircle2 } from "lucide-react";
import { createAcademicYear, setActiveAcademicYear } from "@/lib/actions/academic";
import type { Tables } from "@/lib/supabase/database.types";
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  CardDescription,
} from "@/components/ui/card";
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
    <Card>
      <CardHeader className="flex-row items-start justify-between space-y-0">
        <div>
          <CardTitle>Academic years</CardTitle>
          <CardDescription>Exactly one year is active at a time.</CardDescription>
        </div>
        <Dialog open={open} onOpenChange={setOpen}>
          <DialogTrigger asChild>
            <Button variant="outline" className="gap-2">
              <CalendarPlus className="size-4" /> Add year
            </Button>
          </DialogTrigger>
          <DialogContent>
            <DialogHeader>
              <DialogTitle>Add an academic year</DialogTitle>
              <DialogDescription>
                e.g. &ldquo;2025-26&rdquo;, running June to April.
              </DialogDescription>
            </DialogHeader>
            <form action={formAction} className="space-y-4">
              <div className="space-y-2">
                <Label htmlFor="year-name">Name</Label>
                <Input id="year-name" name="name" placeholder="2025-26" required />
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-2">
                  <Label htmlFor="startDate">Start date</Label>
                  <Input id="startDate" name="startDate" type="date" required />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="endDate">End date</Label>
                  <Input id="endDate" name="endDate" type="date" required />
                </div>
              </div>
              <div className="flex items-center gap-2">
                <Checkbox id="isActive" name="isActive" defaultChecked />
                <Label htmlFor="isActive" className="font-normal">
                  Make this the active year
                </Label>
              </div>
              {state?.error && (
                <p className="text-sm text-destructive">{state.error}</p>
              )}
              <DialogFooter>
                <Button type="submit" disabled={pending}>
                  {pending ? "Adding…" : "Add year"}
                </Button>
              </DialogFooter>
            </form>
          </DialogContent>
        </Dialog>
      </CardHeader>
      <CardContent className="divide-y divide-border">
        {years.length === 0 ? (
          <p className="py-6 text-center text-sm text-muted-foreground">
            No academic years yet. Add one to start creating sections.
          </p>
        ) : (
          years.map((y) => (
            <div key={y.id} className="flex items-center gap-3 py-3">
              <div className="min-w-0 flex-1">
                <p className="font-medium">{y.name}</p>
                <p className="text-xs text-muted-foreground">
                  {fmt(y.start_date)} – {fmt(y.end_date)}
                </p>
              </div>
              {y.is_active ? (
                <Badge variant="success" className="gap-1">
                  <CheckCircle2 className="size-3" /> Active
                </Badge>
              ) : (
                <Button
                  variant="ghost"
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
