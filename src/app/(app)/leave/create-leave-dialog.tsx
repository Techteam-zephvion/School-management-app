"use client";

import { useActionState, useState } from "react";
import { toast } from "sonner";
import { CalendarPlus, Loader2 } from "lucide-react";
import { createLeave } from "@/lib/actions/leave";
import type { StudentPick } from "./page";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
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

export function CreateLeaveDialog({ students }: { students: StudentPick[] }) {
  const [open, setOpen] = useState(false);
  const [studentId, setStudentId] = useState("");

  const [state, formAction, pending] = useActionState(
    async (prev: Awaited<ReturnType<typeof createLeave>>, fd: FormData) => {
      fd.set("studentId", studentId);
      const result = await createLeave(prev, fd);
      if (!result?.error) {
        toast.success("Leave recorded.");
        setOpen(false);
        setStudentId("");
      }
      return result;
    },
    undefined
  );

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button className="gap-2 bg-primary text-primary-foreground hover:bg-primary/80">
          <CalendarPlus className="size-4" /> Record leave
        </Button>
      </DialogTrigger>
      <DialogContent className="sm:max-w-lg">
        <DialogHeader>
          <div className="flex items-center gap-3">
            <span className="flex size-9 shrink-0 items-center justify-center rounded-xl bg-blue-50 text-blue-700 ring-1 ring-blue-100">
              <CalendarPlus className="size-4.5" />
            </span>
            <div>
              <DialogTitle>Record a leave request</DialogTitle>
              <DialogDescription>
                For a leave a parent has phoned in. Approve it to mark the days excused.
              </DialogDescription>
            </div>
          </div>
        </DialogHeader>
        <form action={formAction} className="space-y-5">
          <div className="space-y-2">
            <Label className="text-xs font-semibold text-slate-600">Student</Label>
            <Select value={studentId} onValueChange={setStudentId}>
              <SelectTrigger className="w-full">
                <SelectValue placeholder="Choose a student" />
              </SelectTrigger>
              <SelectContent>
                {students.map((s) => (
                  <SelectItem key={s.id} value={s.id}>
                    {s.label}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-2">
              <Label htmlFor="fromDate" className="text-xs font-semibold text-slate-600">From</Label>
              <Input id="fromDate" name="fromDate" type="date" required />
            </div>
            <div className="space-y-2">
              <Label htmlFor="toDate" className="text-xs font-semibold text-slate-600">To</Label>
              <Input id="toDate" name="toDate" type="date" required />
            </div>
          </div>
          <div className="space-y-2">
            <Label htmlFor="reason" className="text-xs font-semibold text-slate-600">Reason (optional)</Label>
            <Textarea id="reason" name="reason" rows={2} placeholder="Fever, family function…" />
          </div>
          {state?.error && (
            <div className="rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
              {state.error}
            </div>
          )}
          <DialogFooter className="gap-2 sm:gap-0">
            <Button type="submit" disabled={pending || !studentId} className="gap-2 bg-primary text-primary-foreground hover:bg-primary/80">
              {pending && <Loader2 className="size-4 animate-spin" />}
              Record leave
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
