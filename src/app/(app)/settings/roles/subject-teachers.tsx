"use client";

import { useActionState, useRef, useTransition } from "react";
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

type SectionRow = { id: string; label: string };
type Option = { id: string; name: string };
type Assignment = {
  id: string;
  teacher: string;
  section: string;
  subject: string;
};

export function SubjectTeachers({
  sections,
  subjects,
  staff,
  assignments,
}: {
  sections: SectionRow[];
  subjects: Option[];
  staff: Option[];
  assignments: Assignment[];
}) {
  const formRef = useRef<HTMLFormElement>(null);
  const [isPending, startTransition] = useTransition();

  const [state, formAction, pending] = useActionState(
    async (prev: Awaited<ReturnType<typeof assignSubjectTeacher>>, fd: FormData) => {
      const result = await assignSubjectTeacher(prev, fd);
      if (!result?.error) {
        toast.success("Subject teacher assigned.");
        formRef.current?.reset();
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

  const ready = sections.length > 0 && subjects.length > 0 && staff.length > 0;

  return (
    <Card>
      <CardHeader>
        <CardTitle>Subject teachers</CardTitle>
        <CardDescription>
          Assign a teacher to teach a subject in a section.
        </CardDescription>
      </CardHeader>
      <CardContent className="space-y-5">
        {ready ? (
          <form
            ref={formRef}
            action={formAction}
            className="grid gap-3 sm:grid-cols-[1fr_1fr_1fr_auto] sm:items-end"
          >
            <div className="space-y-1.5">
              <Label>Teacher</Label>
              <Select name="staffId">
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
              <Select name="sectionId">
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
              <Select name="subjectId">
                <SelectTrigger className="w-full">
                  <SelectValue placeholder="Subject" />
                </SelectTrigger>
                <SelectContent>
                  {subjects.map((s) => (
                    <SelectItem key={s.id} value={s.id}>
                      {s.name}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <Button type="submit" disabled={pending} className="gap-1.5">
              <Plus className="size-4" /> Assign
            </Button>
          </form>
        ) : (
          <p className="text-sm text-muted-foreground">
            You need at least one section, one subject, and one staff member
            before assigning subject teachers.
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
