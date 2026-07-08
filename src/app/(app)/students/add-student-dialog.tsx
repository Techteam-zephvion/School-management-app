"use client";

import { useActionState, useState } from "react";
import { toast } from "sonner";
import { UserPlus, Loader2 } from "lucide-react";
import { createStudent } from "@/lib/actions/students";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
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

type SectionOption = { id: string; label: string };

export function AddStudentDialog({
  sections,
  hasActiveYear,
  sectionRequired = false,
}: {
  sections: SectionOption[];
  hasActiveYear: boolean;
  sectionRequired?: boolean;
}) {
  const [open, setOpen] = useState(false);
  const [gender, setGender] = useState("");
  const [sectionId, setSectionId] = useState("");

  const [state, formAction, pending] = useActionState(
    async (prev: Awaited<ReturnType<typeof createStudent>>, fd: FormData) => {
      const result = await createStudent(prev, fd);
      if (!result?.error) {
        toast.success("Student added.");
        setOpen(false);
        setGender("");
        setSectionId("");
      }
      return result;
    },
    undefined
  );

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button className="gap-2 bg-[#10203f] text-white hover:bg-[#1b2d5e]">
          <UserPlus className="size-4" /> Add student
        </Button>
      </DialogTrigger>
      <DialogContent className="max-h-[90vh] overflow-y-auto rounded-2xl border-slate-200/80 shadow-xl shadow-slate-950/10">
        <DialogHeader>
          <DialogTitle className="text-xl font-bold tracking-tight text-slate-900">Add a student</DialogTitle>
          <DialogDescription className="text-slate-500">
            Enrolment and guardians can be added afterwards too.
          </DialogDescription>
        </DialogHeader>
        <form action={formAction} className="space-y-4">
          <input type="hidden" name="gender" value={gender} />
          <input type="hidden" name="sectionId" value={sectionId} />

          <div className="grid gap-4 sm:grid-cols-2">
            <div className="space-y-2">
              <Label htmlFor="admissionNo">Admission no.</Label>
              <Input id="admissionNo" name="admissionNo" placeholder="ADM-2025-001" required className="border-slate-200/80 focus-visible:ring-blue-500" />
            </div>
            <div className="space-y-2">
              <Label htmlFor="rollNo">Roll no. (optional)</Label>
              <Input id="rollNo" name="rollNo" placeholder="12" className="border-slate-200/80 focus-visible:ring-blue-500" />
            </div>
          </div>

          <div className="grid gap-4 sm:grid-cols-2">
            <div className="space-y-2">
              <Label htmlFor="firstName">First name</Label>
              <Input id="firstName" name="firstName" required className="border-slate-200/80 focus-visible:ring-blue-500" />
            </div>
            <div className="space-y-2">
              <Label htmlFor="lastName">Last name</Label>
              <Input id="lastName" name="lastName" className="border-slate-200/80 focus-visible:ring-blue-500" />
            </div>
          </div>

          <div className="grid gap-4 sm:grid-cols-2">
            <div className="space-y-2">
              <Label htmlFor="dob">Date of birth</Label>
              <Input id="dob" name="dob" type="date" className="border-slate-200/80 focus-visible:ring-blue-500" />
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

          <div className="space-y-2">
            <Label>Enrol into section{sectionRequired ? "" : " (optional)"}</Label>
            <Select
              value={sectionId}
              onValueChange={setSectionId}
              disabled={!hasActiveYear || sections.length === 0}
            >
              <SelectTrigger className="w-full border-slate-200/80 focus-visible:ring-blue-500">
                <SelectValue
                  placeholder={
                    !hasActiveYear
                      ? "Set an active year first"
                      : sections.length === 0
                        ? "No sections yet"
                        : "Choose a section"
                  }
                />
              </SelectTrigger>
              <SelectContent>
                {sections.map((s) => (
                  <SelectItem key={s.id} value={s.id}>
                    {s.label}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>

          {state?.error && (
            <p className="rounded-lg border border-red-100 bg-red-50/80 px-3 py-2 text-sm text-red-700">
              {state.error}
            </p>
          )}

          <DialogFooter>
            <Button
              type="submit"
              disabled={pending || (sectionRequired && !sectionId)}
              className="gap-2 bg-[#10203f] text-white hover:bg-[#1b2d5e]"
            >
              {pending && <Loader2 className="size-4 animate-spin" />}
              {pending ? "Adding…" : "Add student"}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
