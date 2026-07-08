"use client";

import { useActionState, useState } from "react";
import { toast } from "sonner";
import { Pencil, Loader2 } from "lucide-react";
import { updateStudent } from "@/lib/actions/students";
import type { Tables } from "@/lib/supabase/database.types";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
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

export function EditStudentDialog({ student }: { student: Tables<"students"> }) {
  const [open, setOpen] = useState(false);
  const [gender, setGender] = useState(student.gender ?? "");

  const [state, formAction, pending] = useActionState(
    async (prev: Awaited<ReturnType<typeof updateStudent>>, fd: FormData) => {
      const result = await updateStudent(prev, fd);
      if (!result?.error) {
        toast.success("Student updated.");
        setOpen(false);
      }
      return result;
    },
    undefined
  );

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button variant="outline" size="sm" className="gap-2 border-slate-200/80 text-slate-700 hover:bg-slate-50 hover:text-slate-900">
          <Pencil className="size-4" /> Edit
        </Button>
      </DialogTrigger>
      <DialogContent className="max-h-[90vh] overflow-y-auto rounded-2xl border-slate-200/80 shadow-xl shadow-slate-950/10">
        <DialogHeader>
          <DialogTitle className="text-xl font-bold tracking-tight text-slate-900">Edit student</DialogTitle>
        </DialogHeader>
        <form action={formAction} className="space-y-4">
          <input type="hidden" name="studentId" value={student.id} />
          <input type="hidden" name="gender" value={gender} />
          <div className="grid gap-4 sm:grid-cols-2">
            <div className="space-y-2">
              <Label htmlFor="firstName">First name</Label>
              <Input id="firstName" name="firstName" defaultValue={student.first_name} required className="border-slate-200/80 focus-visible:ring-blue-500" />
            </div>
            <div className="space-y-2">
              <Label htmlFor="lastName">Last name</Label>
              <Input id="lastName" name="lastName" defaultValue={student.last_name ?? ""} className="border-slate-200/80 focus-visible:ring-blue-500" />
            </div>
          </div>
          <div className="grid gap-4 sm:grid-cols-2">
            <div className="space-y-2">
              <Label htmlFor="dob">Date of birth</Label>
              <Input id="dob" name="dob" type="date" defaultValue={student.dob ?? ""} className="border-slate-200/80 focus-visible:ring-blue-500" />
            </div>
            <div className="space-y-2">
              <Label>Gender</Label>
              <Select value={gender} onValueChange={setGender}>
                <SelectTrigger className="w-full border-slate-200/80 focus-visible:ring-blue-500">
                  <SelectValue placeholder="Select" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="male">Male</SelectItem>
                  <SelectItem value="female">Female</SelectItem>
                  <SelectItem value="other">Other</SelectItem>
                </SelectContent>
              </Select>
            </div>
          </div>
          <div className="grid gap-4 sm:grid-cols-2">
            <div className="space-y-2">
              <Label htmlFor="bloodGroup">Blood group</Label>
              <Input id="bloodGroup" name="bloodGroup" defaultValue={student.blood_group ?? ""} placeholder="O+" className="border-slate-200/80 focus-visible:ring-blue-500" />
            </div>
          </div>
          <div className="space-y-2">
            <Label htmlFor="address">Address</Label>
            <Input id="address" name="address" defaultValue={student.address ?? ""} className="border-slate-200/80 focus-visible:ring-blue-500" />
          </div>
          {state?.error && (
            <p className="rounded-lg border border-red-100 bg-red-50/80 px-3 py-2 text-sm text-red-700">
              {state.error}
            </p>
          )}
          <DialogFooter>
            <Button              type="submit" disabled={pending} className="gap-2 bg-[#10203f] text-white hover:bg-[#1b2d5e]"
            >
              {pending && <Loader2 className="size-4 animate-spin" />}
              {pending ? "Saving…" : "Save changes"}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
