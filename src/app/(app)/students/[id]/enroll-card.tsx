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
    <Card>
      <CardHeader>
        <CardTitle>Enrolment{yearName ? ` · ${yearName}` : ""}</CardTitle>
      </CardHeader>
      <CardContent className="space-y-3">
        <div className="flex items-center gap-2.5 text-sm">
          <GraduationCap className="size-4 text-muted-foreground" />
          <span className="font-medium">
            {currentSectionLabel ?? "Not enrolled"}
            {currentRollNo ? ` · Roll ${currentRollNo}` : ""}
          </span>
        </div>

        {canEdit &&
          (!hasActiveYear ? (
            <p className="text-xs text-muted-foreground">
              Set an active academic year to enrol.
            </p>
          ) : editing ? (
            <form action={formAction} className="space-y-3">
              <input type="hidden" name="studentId" value={studentId} />
              <input type="hidden" name="sectionId" value={sectionId} />
              <div className="space-y-1.5">
                <Label>Section</Label>
                <Select value={sectionId} onValueChange={setSectionId}>
                  <SelectTrigger className="w-full">
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
                <Input id="rollNo" name="rollNo" defaultValue={currentRollNo ?? ""} />
              </div>
              {state?.error && <p className="text-sm text-destructive">{state.error}</p>}
              <div className="flex gap-2">
                <Button type="submit" size="sm" disabled={pending || !sectionId} className="gap-2">
                  {pending && <Loader2 className="size-4 animate-spin" />}
                  Save
                </Button>
                <Button type="button" size="sm" variant="ghost" onClick={() => setEditing(false)}>
                  Cancel
                </Button>
              </div>
            </form>
          ) : (
            <Button size="sm" variant="outline" onClick={() => setEditing(true)}>
              {currentSectionLabel ? "Change section" : "Enrol into section"}
            </Button>
          ))}
      </CardContent>
    </Card>
  );
}
