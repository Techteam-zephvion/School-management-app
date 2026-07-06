"use client";

import { useActionState, useState, useTransition } from "react";
import { toast } from "sonner";
import { Plus, X, Loader2 } from "lucide-react";
import { upsertExamSubject, deleteExamSubject } from "@/lib/actions/exams";
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

type ClassOption = { id: string; name: string };
type ExamSubject = {
  id: string;
  classId: string;
  subjectId: string;
  subjectName: string;
  maxMarks: number;
};

export function ExamSubjectsCard({
  termId,
  classes,
  subjectName,
  subjectsByClass,
  examSubjects,
}: {
  termId: string;
  classes: ClassOption[];
  subjectName: Record<string, string>;
  subjectsByClass: Record<string, string[]>;
  examSubjects: ExamSubject[];
}) {
  const [open, setOpen] = useState(false);
  const [classId, setClassId] = useState("");
  const [subjectId, setSubjectId] = useState("");
  const [isPending, startTransition] = useTransition();

  const [state, formAction, pending] = useActionState(
    async (prev: Awaited<ReturnType<typeof upsertExamSubject>>, fd: FormData) => {
      fd.set("termId", termId);
      fd.set("classId", classId);
      fd.set("subjectId", subjectId);
      const result = await upsertExamSubject(prev, fd);
      if (!result?.error) {
        toast.success("Subject added.");
        setOpen(false);
        setClassId("");
        setSubjectId("");
      }
      return result;
    },
    undefined
  );

  function remove(id: string, name: string) {
    startTransition(async () => {
      const result = await deleteExamSubject(id, termId);
      if (result?.error) toast.error(result.error);
      else toast.success(`Removed ${name}.`);
    });
  }

  const subjectChoices = classId
    ? (subjectsByClass[classId] ?? []).map((sid) => ({ id: sid, name: subjectName[sid] ?? "Subject" }))
    : [];
  const byClass = classes.map((c) => ({
    ...c,
    items: examSubjects.filter((es) => es.classId === c.id),
  }));

  return (
    <Card className="overflow-hidden border-0 shadow-md shadow-muted-foreground/5 ring-1 ring-border/50">
      <CardHeader className="flex-row items-start justify-between space-y-0">
        <div>
          <CardTitle className="text-base">Subjects &amp; max marks</CardTitle>
          <CardDescription>What each class is examined on this term.</CardDescription>
        </div>
        <Dialog open={open} onOpenChange={setOpen}>
          <DialogTrigger asChild>
            <Button variant="outline" className="gap-2">
              <Plus className="size-4" /> Add subject
            </Button>
          </DialogTrigger>
          <DialogContent>
            <DialogHeader>
              <DialogTitle>Add exam subject</DialogTitle>
            </DialogHeader>
            <form action={formAction} className="space-y-4">
              <div className="space-y-2">
                <Label className="text-sm font-medium text-foreground">Class</Label>
                <Select
                  value={classId}
                  onValueChange={(v) => {
                    setClassId(v);
                    setSubjectId("");
                  }}
                >
                  <SelectTrigger className="w-full rounded-lg">
                    <SelectValue placeholder="Choose class" />
                  </SelectTrigger>
                  <SelectContent>
                    {classes.map((c) => (
                      <SelectItem key={c.id} value={c.id}>
                        {c.name}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
              <div className="space-y-2">
                <Label className="text-sm font-medium text-foreground">Subject</Label>
                <Select value={subjectId} onValueChange={setSubjectId} disabled={!classId}>
                  <SelectTrigger className="w-full rounded-lg">
                    <SelectValue
                      placeholder={!classId ? "Pick a class first" : subjectChoices.length === 0 ? "No subjects mapped" : "Choose subject"}
                    />
                  </SelectTrigger>
                  <SelectContent>
                    {subjectChoices.map((s) => (
                      <SelectItem key={s.id} value={s.id}>
                        {s.name}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
              <div className="space-y-2">
                <Label htmlFor="maxMarks" className="text-sm font-medium text-foreground">
                  Max marks
                </Label>
                <Input
                  id="maxMarks"
                  name="maxMarks"
                  type="number"
                  min={1}
                  max={1000}
                  defaultValue={100}
                  required
                  className="w-32 rounded-lg"
                />
              </div>
              {state?.error && <p className="text-sm text-destructive">{state.error}</p>}
              <DialogFooter>
                <Button type="submit" disabled={pending || !classId || !subjectId} className="gap-2">
                  {pending && <Loader2 className="size-4 animate-spin" />}
                  Add subject
                </Button>
              </DialogFooter>
            </form>
          </DialogContent>
        </Dialog>
      </CardHeader>
      <CardContent className="space-y-4">
        {byClass.every((c) => c.items.length === 0) ? (
          <p className="py-2 text-sm text-muted-foreground">
            No subjects yet. Add the subjects each class is examined on, with their max marks.
          </p>
        ) : (
          byClass
            .filter((c) => c.items.length > 0)
            .map((c) => (
              <div key={c.id} className="space-y-2">
                <p className="text-xs font-semibold tracking-wide text-muted-foreground uppercase">
                  {c.name}
                </p>
                <div className="flex flex-wrap gap-2">
                  {c.items.map((es) => (
                    <span
                      key={es.id}
                      className="group inline-flex items-center gap-1.5 rounded-lg border border-border bg-secondary/50 py-1 pl-3 pr-1.5 text-sm font-medium"
                    >
                      {es.subjectName}
                      <Badge variant="outline" className="px-1.5 py-0 text-[11px] font-normal">
                        /{es.maxMarks}
                      </Badge>
                      <button
                        type="button"
                        disabled={isPending}
                        onClick={() => remove(es.id, es.subjectName)}
                        aria-label={`Remove ${es.subjectName}`}
                        className="flex size-5 items-center justify-center rounded text-muted-foreground transition-colors hover:bg-destructive/10 hover:text-destructive"
                      >
                        <X className="size-3.5" />
                      </button>
                    </span>
                  ))}
                </div>
              </div>
            ))
        )}
      </CardContent>
    </Card>
  );
}
