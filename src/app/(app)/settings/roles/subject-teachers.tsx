"use client";

import { useActionState, useState, useTransition } from "react";
import { toast } from "sonner";
import { Plus, X, BookOpen } from "lucide-react";
import { assignSubjectTeacher, removeSubjectTeacher } from "@/lib/actions/academic";
import { Card, CardContent } from "@/components/ui/card";
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

  // Only subjects mapped to the selected section's class are assignable.
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
    <Card className="overflow-hidden border border-slate-200/80 bg-white shadow-sm shadow-slate-950/5 ring-1 ring-slate-900/[0.02]">
      {/* Card header */}
      <div className="border-b border-slate-100 px-5 py-4">
        <div className="flex items-center gap-3">
          <span className="flex size-9 items-center justify-center rounded-xl bg-blue-50 text-blue-700 ring-1 ring-blue-100">
            <BookOpen className="size-4.5" />
          </span>
          <div>
            <h2 className="text-base font-semibold text-slate-900">Subject teachers</h2>
            <p className="text-xs text-slate-500">
              Assign a teacher to a subject in a section. Only subjects mapped to
              that section&apos;s class can be chosen.
            </p>
          </div>
        </div>
      </div>

      <CardContent className="space-y-5 px-5 py-5">
        {ready ? (
          <form
            action={formAction}
            className="grid gap-4 sm:grid-cols-[1fr_1fr_1fr_auto] sm:items-end"
          >
            <input type="hidden" name="staffId" value={staffId} />
            <input type="hidden" name="sectionId" value={sectionId} />
            <input type="hidden" name="subjectId" value={subjectId} />

            <div className="space-y-2">
              <Label className="text-xs font-semibold text-slate-600">Teacher</Label>
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

            <div className="space-y-2">
              <Label className="text-xs font-semibold text-slate-600">Section</Label>
              <Select
                value={sectionId}
                onValueChange={(v) => {
                  setSectionId(v);
                  setSubjectId("");
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

            <div className="space-y-2">
              <Label className="text-xs font-semibold text-slate-600">Subject</Label>
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

            <Button type="submit" disabled={pending || !canSubmit} className="gap-1.5 bg-primary text-primary-foreground hover:bg-primary/80">
              <Plus className="size-4" /> Assign
            </Button>
          </form>
        ) : (
          <div className="flex flex-col items-center gap-4 py-6 text-center">
            <span className="flex size-12 items-center justify-center rounded-2xl bg-slate-50 text-slate-400 ring-1 ring-slate-200">
              <BookOpen className="size-5" />
            </span>
            <div>
              <p className="text-sm font-medium text-slate-700">Set up sections and teachers first</p>
              <p className="mt-0.5 text-xs text-slate-500">
                You need at least one section and one teacher before assigning subject teachers.
              </p>
            </div>
          </div>
        )}

        {sectionId && availableSubjects.length === 0 && (
          <div className="flex items-start gap-3 rounded-lg border border-amber-200/60 bg-amber-50/60 px-4 py-3 text-sm text-amber-900">
            <span>
              This section&apos;s class has no subjects yet. Map subjects to it in{" "}
              <a href="/settings/classes" className="font-medium underline">
                Classes &amp; subjects
              </a>
              .
            </span>
          </div>
        )}

        {state?.error && (
          <div className="rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
            {state.error}
          </div>
        )}

        {/* Assignment list */}
        <div className="overflow-hidden rounded-xl border border-slate-200/80 divide-y divide-slate-100">
          {assignments.length === 0 ? (
            <div className="flex flex-col items-center gap-3 px-5 py-10 text-center">
              <span className="flex size-12 items-center justify-center rounded-2xl bg-slate-50 text-slate-400 ring-1 ring-slate-200">
                <BookOpen className="size-5" />
              </span>
              <div>
                <p className="text-sm font-medium text-slate-700">No subject teachers assigned yet</p>
                <p className="mt-0.5 text-xs text-slate-500">Use the form above to assign teachers to subjects.</p>
              </div>
            </div>
          ) : (
            assignments.map((a) => (
              <div
                key={a.id}
                className="group flex items-center gap-4 px-5 py-4 transition-colors hover:bg-blue-50/50"
              >
                <span className="flex size-10 shrink-0 items-center justify-center rounded-2xl bg-blue-50 text-blue-700 ring-1 ring-blue-100">
                  <BookOpen className="size-5" />
                </span>
                <div className="min-w-0 flex-1">
                  <p className="truncate text-sm font-semibold text-slate-900">{a.teacher}</p>
                  <p className="truncate text-xs text-slate-500">
                    {a.subject} · {a.section}
                  </p>
                </div>
                <Button
                  variant="ghost"
                  size="icon-sm"
                  disabled={isPending}
                  onClick={() => remove(a.id)}
                  aria-label="Remove assignment"
                  className="text-slate-400 hover:text-red-600"
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
