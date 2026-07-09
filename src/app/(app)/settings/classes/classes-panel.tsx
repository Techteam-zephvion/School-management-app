"use client";

import { useActionState, useState, useTransition } from "react";
import { toast } from "sonner";
import { Plus, X, Trash2, BookOpen, ChevronDown, GraduationCap } from "lucide-react";
import {
  createClass,
  deleteClass,
  createSection,
  deleteSection,
  updateClassSubjects,
} from "@/lib/actions/academic";
import {
  Card,
  CardContent,
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
import {
  Popover,
  PopoverContent,
  PopoverTrigger,
} from "@/components/ui/popover";

type Class = { id: string; name: string; sort_order: number };
type Subject = { id: string; name: string; code: string | null };
type Section = { id: string; class_id: string; name: string };
type ClassSubject = { class_id: string; subject_id: string };

export function ClassesPanel({
  classes,
  subjects,
  classSubjects,
  sections,
  canAddSections,
}: {
  classes: Class[];
  subjects: Subject[];
  classSubjects: ClassSubject[];
  sections: Section[];
  canAddSections: boolean;
}) {
  const [open, setOpen] = useState(false);
  const [state, formAction, pending] = useActionState(
    async (prev: Awaited<ReturnType<typeof createClass>>, fd: FormData) => {
      const result = await createClass(prev, fd);
      if (!result?.error) {
        toast.success("Class added.");
        setOpen(false);
      }
      return result;
    },
    undefined
  );

  return (
    <Card className="overflow-hidden border border-slate-200/80 bg-white shadow-sm shadow-slate-950/5 ring-1 ring-slate-900/[0.02]">
      {/* Card header */}
      <div className="flex flex-wrap items-start justify-between gap-3 border-b border-slate-100 px-5 py-4">
        <div className="flex items-center gap-3">
          <span className="flex size-9 items-center justify-center rounded-xl bg-blue-50 text-blue-700 ring-1 ring-blue-100">
            <GraduationCap className="size-4.5" />
          </span>
          <div>
            <h2 className="text-base font-semibold text-slate-900">Classes</h2>
            <p className="text-xs text-slate-500">Each class has sections and a set of subjects.</p>
          </div>
        </div>
        <Dialog open={open} onOpenChange={setOpen}>
          <DialogTrigger asChild>
            <Button className="gap-2 bg-primary text-primary-foreground hover:bg-primary/80">
              <Plus className="size-4" /> Add class
            </Button>
          </DialogTrigger>
          <DialogContent className="sm:max-w-lg">
            <DialogHeader>
              <div className="flex items-center gap-3">
                <span className="flex size-9 shrink-0 items-center justify-center rounded-xl bg-blue-50 text-blue-700 ring-1 ring-blue-100">
                  <GraduationCap className="size-4.5" />
                </span>
                <div>
                  <DialogTitle>Add a class</DialogTitle>
                  <DialogDescription>Create a new grade for the school.</DialogDescription>
                </div>
              </div>
            </DialogHeader>
            <form action={formAction} className="space-y-5">
              <div className="space-y-2">
                <Label htmlFor="class-grade" className="text-xs font-semibold text-slate-600">Grade number</Label>
                <div className="flex items-center gap-2">
                  <span className="text-sm font-medium text-slate-500">Grade</span>
                  <Input
                    id="class-grade"
                    name="gradeNumber"
                    type="number"
                    inputMode="numeric"
                    min={1}
                    max={20}
                    step={1}
                    placeholder="5"
                    className="w-24"
                    required
                  />
                </div>
                <p className="text-xs text-slate-400">
                  Saved as &ldquo;Grade 5&rdquo;. Numbers only.
                </p>
              </div>
              {state?.error && (
                <div className="rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
                  {state.error}
                </div>
              )}
              <DialogFooter className="gap-2 sm:gap-0">
                <Button type="submit" disabled={pending} className="bg-primary text-primary-foreground hover:bg-primary/80">
                  {pending ? "Adding…" : "Add class"}
                </Button>
              </DialogFooter>
            </form>
          </DialogContent>
        </Dialog>
      </div>

      <CardContent className="space-y-4 px-5 py-5">
        {classes.length === 0 ? (
          <div className="flex flex-col items-center gap-4 py-8 text-center">
            <span className="flex size-12 items-center justify-center rounded-2xl bg-slate-50 text-slate-400 ring-1 ring-slate-200">
              <GraduationCap className="size-5" />
            </span>
            <div>
              <p className="text-sm font-medium text-slate-700">No classes yet</p>
              <p className="mt-0.5 text-xs text-slate-500">Add your first grade to get started.</p>
            </div>
          </div>
        ) : (
          classes.map((c) => (
            <ClassCard
              key={c.id}
              klass={c}
              subjects={subjects}
              enabledSubjectIds={classSubjects
                .filter((cs) => cs.class_id === c.id)
                .map((cs) => cs.subject_id)}
              sections={sections.filter((s) => s.class_id === c.id)}
              canAddSections={canAddSections}
            />
          ))
        )}
      </CardContent>
    </Card>
  );
}

function ClassCard({
  klass,
  subjects,
  enabledSubjectIds,
  sections,
  canAddSections,
}: {
  klass: Class;
  subjects: Subject[];
  enabledSubjectIds: string[];
  sections: Section[];
  canAddSections: boolean;
}) {
  const [isPending, startTransition] = useTransition();
  const [enabled, setEnabled] = useState<Set<string>>(new Set(enabledSubjectIds));
  const [addingSection, setAddingSection] = useState(false);
  const [deleteDialogOpen, setDeleteDialogOpen] = useState(false);

  function toggleSubject(subjectId: string, checked: boolean) {
    const next = new Set(enabled);
    if (checked) next.add(subjectId);
    else next.delete(subjectId);
    setEnabled(next);
    startTransition(async () => {
      const result = await updateClassSubjects(klass.id, [...next]);
      if (result?.error) {
        toast.error(result.error);
        setEnabled(new Set(enabledSubjectIds)); // revert
      }
    });
  }

  function removeClass() {
    startTransition(async () => {
      const result = await deleteClass(klass.id);
      if (result?.error) toast.error(result.error);
      else toast.success(`Removed ${klass.name}.`);
    });
  }

  function removeSection(id: string, name: string) {
    startTransition(async () => {
      const result = await deleteSection(id);
      if (result?.error) toast.error(result.error);
      else toast.success(`Removed section ${name}.`);
    });
  }

  const enabledSubjects = subjects.filter((s) => enabled.has(s.id));

  return (
    <div className="rounded-2xl border border-slate-200/80 bg-slate-50/60 p-4 transition-colors hover:border-slate-200">
      {/* Class header */}
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <span className="flex size-8 items-center justify-center rounded-lg bg-blue-50 text-blue-700 ring-1 ring-blue-100">
            <GraduationCap className="size-4" />
          </span>
          <h3 className="text-sm font-semibold text-slate-900">{klass.name}</h3>
        </div>
        <Dialog open={deleteDialogOpen} onOpenChange={setDeleteDialogOpen}>
          <DialogTrigger asChild>
            <Button
              variant="ghost"
              size="icon-sm"
              disabled={isPending}
              aria-label={`Delete ${klass.name}`}
              className="text-slate-400 hover:text-red-600"
            >
              <Trash2 className="size-4" />
            </Button>
          </DialogTrigger>
          <DialogContent>
            <DialogHeader>
              <DialogTitle>Delete {klass.name}?</DialogTitle>
              <DialogDescription>
                This will permanently delete {klass.name} and all its sections, subject mappings, and
                enrollments. This can&apos;t be undone.
              </DialogDescription>
            </DialogHeader>
            <DialogFooter className="gap-2 sm:gap-0">
              <Button variant="outline" onClick={() => setDeleteDialogOpen(false)} disabled={isPending}>
                Cancel
              </Button>
              <Button variant="destructive" onClick={removeClass} disabled={isPending} className="gap-2">
                <Trash2 className="size-4" /> Delete class
              </Button>
            </DialogFooter>
          </DialogContent>
        </Dialog>
      </div>

      {/* Sections */}
      <div className="mt-4">
        <p className="mb-2 text-xs font-semibold uppercase tracking-wide text-slate-500">Sections</p>
        <div className="flex flex-wrap items-center gap-2">
          {sections.map((s) => (
            <span
              key={s.id}
              className="group inline-flex items-center gap-1 rounded-lg border border-slate-200 bg-white py-1 pl-2.5 pr-1 text-sm font-medium shadow-sm"
            >
              {klass.name} · {s.name}
              <button
                type="button"
                disabled={isPending}
                onClick={() => removeSection(s.id, s.name)}
                aria-label={`Remove section ${s.name}`}
                className="flex size-5 items-center justify-center rounded text-slate-400 transition-colors hover:bg-red-50 hover:text-red-600"
              >
                <X className="size-3.5" />
              </button>
            </span>
          ))}
          {canAddSections ? (
            addingSection ? (
              <AddSectionForm
                classId={klass.id}
                onDone={() => setAddingSection(false)}
              />
            ) : (
              <Button
                variant="outline"
                size="sm"
                className="gap-1"
                onClick={() => setAddingSection(true)}
              >
                <Plus className="size-3.5" /> Section
              </Button>
            )
          ) : (
            <span className="text-xs text-slate-400">
              Set an active year to add sections
            </span>
          )}
        </div>
      </div>

      {/* Subjects mapping */}
      <div className="mt-4">
        <p className="mb-2 text-xs font-semibold uppercase tracking-wide text-slate-500">Subjects</p>
        <div className="flex flex-wrap items-center gap-2">
          {enabledSubjects.map((s) => (
            <Badge key={s.id} variant="secondary" className="font-medium">
              {s.name}
            </Badge>
          ))}
          <Popover>
            <PopoverTrigger asChild>
              <Button variant="outline" size="sm" className="gap-1" disabled={subjects.length === 0}>
                <BookOpen className="size-3.5" />
                {enabledSubjects.length > 0 ? "Edit" : "Add subjects"}
                <ChevronDown className="size-3.5" />
              </Button>
            </PopoverTrigger>
            <PopoverContent align="start" className="w-56">
              {subjects.length === 0 ? (
                <p className="text-sm text-slate-500">Add subjects above first.</p>
              ) : (
                <div className="space-y-1.5">
                  {subjects.map((s) => (
                    <label
                      key={s.id}
                      className="flex cursor-pointer items-center gap-2.5 rounded-md px-1.5 py-1.5 text-sm hover:bg-muted"
                    >
                      <Checkbox
                        checked={enabled.has(s.id)}
                        onCheckedChange={(v) => toggleSubject(s.id, v === true)}
                      />
                      {s.name}
                    </label>
                  ))}
                </div>
              )}
            </PopoverContent>
          </Popover>
        </div>
      </div>
    </div>
  );
}

function AddSectionForm({
  classId,
  onDone,
}: {
  classId: string;
  onDone: () => void;
}) {
  const [state, formAction, pending] = useActionState(
    async (prev: Awaited<ReturnType<typeof createSection>>, fd: FormData) => {
      const result = await createSection(prev, fd);
      if (!result?.error) {
        toast.success("Section added.");
        onDone();
      } else {
        toast.error(result.error);
      }
      return result;
    },
    undefined
  );

  return (
    <span className="inline-flex flex-col gap-1">
      <form action={formAction} className="flex items-center gap-1.5">
        <input type="hidden" name="classId" value={classId} />
        <Input
          name="name"
          placeholder="A"
          autoFocus
          required
          className="h-8 w-16"
        />
        <Button type="submit" size="sm" disabled={pending} className="bg-primary text-primary-foreground hover:bg-primary/80">
          {pending ? "…" : "Add"}
        </Button>
        <Button type="button" size="sm" variant="ghost" onClick={onDone}>
          Cancel
        </Button>
      </form>
      {state?.error ? (
        <span className="text-xs text-red-600">{state.error}</span>
      ) : null}
    </span>
  );
}
