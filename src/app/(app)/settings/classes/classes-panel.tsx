"use client";

import { useActionState, useState, useTransition } from "react";
import { toast } from "sonner";
import { Plus, X, Trash2, BookOpen, ChevronDown } from "lucide-react";
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
    <Card>
      <CardHeader className="flex-row items-start justify-between space-y-0">
        <div>
          <CardTitle>Classes</CardTitle>
          <CardDescription>
            Each class has sections and a set of subjects.
          </CardDescription>
        </div>
        <Dialog open={open} onOpenChange={setOpen}>
          <DialogTrigger asChild>
            <Button className="gap-2">
              <Plus className="size-4" /> Add class
            </Button>
          </DialogTrigger>
          <DialogContent>
            <DialogHeader>
              <DialogTitle>Add a class</DialogTitle>
            </DialogHeader>
            <form action={formAction} className="space-y-4">
              <div className="space-y-2">
                <Label htmlFor="class-name">Name</Label>
                <Input id="class-name" name="name" placeholder="Grade 5" required />
              </div>
              <div className="space-y-2">
                <Label htmlFor="class-order">Sort order (optional)</Label>
                <Input
                  id="class-order"
                  name="sortOrder"
                  type="number"
                  placeholder="5"
                />
              </div>
              {state?.error && (
                <p className="text-sm text-destructive">{state.error}</p>
              )}
              <DialogFooter>
                <Button type="submit" disabled={pending}>
                  {pending ? "Adding…" : "Add class"}
                </Button>
              </DialogFooter>
            </form>
          </DialogContent>
        </Dialog>
      </CardHeader>
      <CardContent className="space-y-3">
        {classes.length === 0 ? (
          <p className="py-2 text-sm text-muted-foreground">
            No classes yet. Add your first grade to get started.
          </p>
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
    <div className="rounded-xl border border-border p-4">
      <div className="flex items-center justify-between">
        <h3 className="font-semibold">{klass.name}</h3>
        <Button
          variant="ghost"
          size="icon-sm"
          disabled={isPending}
          onClick={removeClass}
          aria-label={`Delete ${klass.name}`}
          className="text-muted-foreground hover:text-destructive"
        >
          <Trash2 className="size-4" />
        </Button>
      </div>

      {/* sections */}
      <div className="mt-3">
        <p className="mb-1.5 text-xs font-medium text-muted-foreground">Sections</p>
        <div className="flex flex-wrap items-center gap-2">
          {sections.map((s) => (
            <span
              key={s.id}
              className="group inline-flex items-center gap-1 rounded-md border border-border bg-secondary/60 py-1 pl-2.5 pr-1 text-sm font-medium"
            >
              {klass.name} · {s.name}
              <button
                type="button"
                disabled={isPending}
                onClick={() => removeSection(s.id, s.name)}
                aria-label={`Remove section ${s.name}`}
                className="flex size-5 items-center justify-center rounded text-muted-foreground hover:bg-destructive/10 hover:text-destructive"
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
            <span className="text-xs text-muted-foreground">
              Set an active year to add sections
            </span>
          )}
        </div>
      </div>

      {/* subjects mapping */}
      <div className="mt-3">
        <p className="mb-1.5 text-xs font-medium text-muted-foreground">Subjects</p>
        <div className="flex flex-wrap items-center gap-2">
          {enabledSubjects.map((s) => (
            <Badge key={s.id} variant="secondary">
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
                <p className="text-sm text-muted-foreground">
                  Add subjects above first.
                </p>
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
    <form action={formAction} className="flex items-center gap-1.5">
      <input type="hidden" name="classId" value={classId} />
      <Input
        name="name"
        placeholder="A"
        autoFocus
        required
        className="h-8 w-16"
      />
      <Button type="submit" size="sm" disabled={pending}>
        {pending ? "…" : "Add"}
      </Button>
      <Button type="button" size="sm" variant="ghost" onClick={onDone}>
        Cancel
      </Button>
      {state?.error ? <span className="sr-only">{state.error}</span> : null}
    </form>
  );
}
