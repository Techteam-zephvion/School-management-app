"use client";

import { useActionState, useState } from "react";
import { toast } from "sonner";
import { GraduationCap, Loader2 } from "lucide-react";
import { enrollStudent } from "@/lib/actions/students";
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";

type SectionOption = { id: string; label: string };

export function EnrollCard({
  studentId,
  currentSectionLabel,
  currentRollNo,
  sections,
  hasActiveYear,
  yearName,
  canEdit,
}: {
  studentId: string;
  currentSectionLabel: string | null;
  currentRollNo: string | null;
  sections: SectionOption[];
  hasActiveYear: boolean;
  yearName: string | null;
  canEdit: boolean;
}) {
  const [editing, setEditing] = useState(false);
  const [sectionId, setSectionId] = useState("");

  const [state, formAction, pending] = useActionState(
    async (prev: Awaited<ReturnType<typeof enrollStudent>>, fd: FormData) => {
      const result = await enrollStudent(prev, fd);
      if (!result?.error) {
        toast.success("Enrolment updated.");
        setEditing(false);
        setSectionId("");
      }
      return result;
    },
    undefined
  );

  return (
    <Card className="border border-slate-200/80 bg-white/95 shadow-sm shadow-slate-950/5 ring-1 ring-slate-900/[0.02]">
      <CardHeader className="pb-3">
        <CardTitle className="flex items-center gap-2 text-base font-semibold text-slate-900">
          <span className="flex size-8 items-center justify-center rounded-xl bg-blue-50 text-blue-700 ring-1 ring-blue-100">
            <GraduationCap className="size-4" />
          </span>
          Enrolment{yearName ? ` · ${yearName}` : ""}
        </CardTitle>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="flex items-center gap-3 rounded-xl border border-slate-100 bg-slate-50/60 px-3.5 py-3">
          <span className="flex size-8 shrink-0 items-center justify-center rounded-xl bg-white text-blue-700 ring-1 ring-blue-100">
            <GraduationCap className="size-4" />
          </span>
          <div className="min-w-0">
            <p className="text-sm font-semibold text-slate-900">
              {currentSectionLabel ?? "Not enrolled"}
            </p>
            {currentRollNo && (
              <p className="mt-0.5 text-xs text-slate-500">Roll no. {currentRollNo}</p>
            )}
          </div>
        </div>

        {canEdit &&
          (!hasActiveYear ? (
            <p className="rounded-lg border border-amber-100 bg-amber-50/80 px-3 py-2 text-xs text-amber-700">
              Set an active academic year to enrol.
            </p>
          ) : editing ? (
            <form action={formAction} className="space-y-3">
              <input type="hidden" name="studentId" value={studentId} />
              <input type="hidden" name="sectionId" value={sectionId} />
              <div className="space-y-1.5">
                <Label>Section</Label>
                <Select value={sectionId} onValueChange={setSectionId}>
                  <SelectTrigger className="w-full border-slate-200/80 focus-visible:ring-blue-500">
                    <SelectValue placeholder="Choose a section" />
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
              <div className="space-y-1.5">
                <Label htmlFor="rollNo">Roll no. (optional)</Label>
                <Input id="rollNo" name="rollNo" defaultValue={currentRollNo ?? ""} className="border-slate-200/80 focus-visible:ring-blue-500" />
              </div>
              {state?.error && <p className="text-sm text-destructive">{state.error}</p>}
              <div className="flex gap-2">
                <Button type="submit" size="sm" disabled={pending || !sectionId} className="gap-2 bg-[#10203f] text-white hover:bg-[#1b2d5e]">
                  {pending && <Loader2 className="size-4 animate-spin" />}
                  Save
                </Button>
                <Button type="button" size="sm" variant="ghost" className="text-slate-600 hover:bg-slate-100" onClick={() => setEditing(false)}>
                  Cancel
                </Button>
              </div>
            </form>
          ) : (
            <Button size="sm" variant="outline" className="border-slate-200/80 text-slate-700 hover:bg-slate-50 hover:text-slate-900" onClick={() => setEditing(true)}>
              {currentSectionLabel ? "Change section" : "Enrol into section"}
            </Button>
          ))}
      </CardContent>
    </Card>
  );
}
