"use client";

import { useActionState, useState, useTransition } from "react";
import { toast } from "sonner";
import { Plus, X } from "lucide-react";
import { assignSubjectTeacher, removeSubjectTeacher } from "@/lib/actions/academic";
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  CardDescription,
} from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";

type SectionRow = { id: string; classId: string; label: string };
type Option = { id: string; name: string };
type ClassSubject = { class_id: string; subject_id: string };
type Assignment = {
  id: string;
  teacher: string;
  section: string;
  subject: string;
};

export function SubjectTeachers({
  sections,
  subjects,
  classSubjects,
  staff,
  assignments,
}: {
  sections: SectionRow[];
  subjects: Option[];
  classSubjects: ClassSubject[];
  staff: Option[];
  assignments: Assignment[];
}) {
  const [isPending, startTransition] = useTransition();
  const [staffId, setStaffId] = useState("");
  const [sectionId, setSectionId] = useState("");
  const [subjectId, setSubjectId] = useState("");

  const [state, formAction, pending] = useActionState(
    async (prev: Awaited<ReturnType<typeof assignSubjectTeacher>>, fd: FormData) => {
      const result = await assignSubjectTeacher(prev, fd);
      if (!result?.error) {
        toast.success("Subject teacher assigned.");
        setStaffId("");
        setSectionId("");
        setSubjectId("");
      }
      return result;
    },
    undefined
  );

  function remove(id: string) {
    startTransition(async () => {
      const result = await removeSubjectTeacher(id);
      if (result?.error) toast.error(result.error);
      else toast.success("Assignment removed.");
    });
  }

  // Only subjects mapped to the selected section's class are assignable (doc 03).
  const selectedSection = sections.find((s) => s.id === sectionId);
  const allowedIds = new Set(
    classSubjects
      .filter((cs) => cs.class_id === selectedSection?.classId)
      .map((cs) => cs.subject_id)
  );
  const availableSubjects = subjects.filter((s) => allowedIds.has(s.id));

  const ready = sections.length > 0 && staff.length > 0;
  const canSubmit = Boolean(staffId && sectionId && subjectId);

  return (
    <Card>
      <CardHeader>
        <CardTitle>Subject teachers</CardTitle>
        <CardDescription>
          Assign a teacher to a subject in a section. Only subjects mapped to
          that section&apos;s class can be chosen.
        </CardDescription>
      </CardHeader>
      <CardContent className="space-y-5">
        {ready ? (
          <form
            action={formAction}
            className="grid gap-3 sm:grid-cols-[1fr_1fr_1fr_auto] sm:items-end"
          >
            <input type="hidden" name="staffId" value={staffId} />
            <input type="hidden" name="sectionId" value={sectionId} />
            <input type="hidden" name="subjectId" value={subjectId} />

            <div className="space-y-1.5">
              <Label>Teacher</Label>
              <Select value={staffId} onValueChange={setStaffId}>
                <SelectTrigger className="w-full">
                  <SelectValue placeholder="Teacher" />
                </SelectTrigger>
                <SelectContent>
                  {staff.map((t) => (
                    <SelectItem key={t.id} value={t.id}>
                      {t.name}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

            <div className="space-y-1.5">
              <Label>Section</Label>
              <Select
                value={sectionId}
                onValueChange={(v) => {
                  setSectionId(v);
                  setSubjectId(""); // subject options depend on the class
                }}
              >
                <SelectTrigger className="w-full">
                  <SelectValue placeholder="Section" />
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
              <Label>Subject</Label>
              <Select
                value={subjectId}
                onValueChange={setSubjectId}
                disabled={!sectionId || availableSubjects.length === 0}
              >
                <SelectTrigger className="w-full">
                  <SelectValue
                    placeholder={
                      !sectionId
                        ? "Pick a section first"
                        : availableSubjects.length === 0
                          ? "No subjects mapped"
                          : "Subject"
                    }
                  />
                </SelectTrigger>
                <SelectContent>
                  {availableSubjects.map((s) => (
                    <SelectItem key={s.id} value={s.id}>
                      {s.name}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

            <Button type="submit" disabled={pending || !canSubmit} className="gap-1.5">
              <Plus className="size-4" /> Assign
            </Button>
          </form>
        ) : (
          <p className="text-sm text-muted-foreground">
            You need at least one section and one teacher before assigning
            subject teachers.
          </p>
        )}

        {sectionId && availableSubjects.length === 0 && (
          <p className="text-sm text-muted-foreground">
            This section&apos;s class has no subjects yet. Map subjects to it in{" "}
            <a href="/settings/classes" className="font-medium text-accent underline">
              Classes &amp; subjects
            </a>
            .
          </p>
        )}

        {state?.error && <p className="text-sm text-destructive">{state.error}</p>}

        <div className="divide-y divide-border rounded-xl border border-border">
          {assignments.length === 0 ? (
            <p className="px-4 py-5 text-center text-sm text-muted-foreground">
              No subject teachers assigned yet.
            </p>
          ) : (
            assignments.map((a) => (
              <div key={a.id} className="flex items-center gap-3 px-4 py-3">
                <div className="min-w-0 flex-1">
                  <p className="font-medium">{a.teacher}</p>
                  <p className="text-xs text-muted-foreground">
                    {a.subject} · {a.section}
                  </p>
                </div>
                <Button
                  variant="ghost"
                  size="icon-sm"
                  disabled={isPending}
                  onClick={() => remove(a.id)}
                  aria-label="Remove assignment"
                  className="text-muted-foreground hover:text-destructive"
                >
                  <X className="size-4" />
                </Button>
              </div>
            ))
          )}
        </div>
      </CardContent>
    </Card>
  );
}
