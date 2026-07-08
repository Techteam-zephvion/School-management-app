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
    <Card className="overflow-hidden border border-slate-200/80 bg-white/95 shadow-sm shadow-slate-950/5 ring-1 ring-slate-900/[0.02]">
      <CardHeader className="flex-row items-start justify-between space-y-0 pb-3">
        <div className="min-w-0">
          <CardTitle className="flex items-center gap-2 text-base font-semibold text-slate-900">
            <span className="flex size-8 items-center justify-center rounded-xl bg-blue-50 text-blue-700 ring-1 ring-blue-100">
              <Plus className="size-4" />
            </span>
            Subjects &amp; max marks
          </CardTitle>
          <CardDescription className="mt-1.5 text-slate-500">
            What each class is examined on this term.
          </CardDescription>
        </div>
        <Dialog open={open} onOpenChange={setOpen}>
          <DialogTrigger asChild>
            <Button variant="outline" className="gap-2 border-slate-200/80 text-slate-700 hover:bg-slate-50 hover:text-slate-900">
              <Plus className="size-4" /> Add subject
            </Button>
          </DialogTrigger>
          <DialogContent className="rounded-2xl border-slate-200/80 shadow-xl shadow-slate-950/10">
            <DialogHeader>
              <DialogTitle className="text-xl font-bold tracking-tight text-slate-900">Add exam subject</DialogTitle>
            </DialogHeader>
            <form action={formAction} className="space-y-4">
              <div className="space-y-2">
                <Label className="text-xs font-semibold uppercase tracking-wide text-slate-500">Class</Label>
                <Select
                  value={classId}
                  onValueChange={(v) => {
                    setClassId(v);
                    setSubjectId("");
                  }}
                >
                  <SelectTrigger className="w-full border-slate-200/80 focus-visible:ring-blue-500">
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
                <Label className="text-xs font-semibold uppercase tracking-wide text-slate-500">Subject</Label>
                <Select value={subjectId} onValueChange={setSubjectId} disabled={!classId}>
                  <SelectTrigger className="w-full border-slate-200/80 focus-visible:ring-blue-500">
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
                <Label htmlFor="maxMarks" className="text-xs font-semibold uppercase tracking-wide text-slate-500">
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
                  className="w-32 border-slate-200/80 focus-visible:ring-blue-500"
                />
              </div>
              {state?.error && (
                <p className="rounded-lg border border-red-100 bg-red-50/80 px-3 py-2 text-sm text-red-700">
                  {state.error}
                </p>
              )}
              <DialogFooter>
                <Button type="submit" disabled={pending || !classId || !subjectId} className="gap-2 bg-[#10203f] text-white hover:bg-[#1b2d5e]">
                  {pending && <Loader2 className="size-4 animate-spin" />}
                  Add subject
                </Button>
              </DialogFooter>
            </form>
          </DialogContent>
        </Dialog>
      </CardHeader>
      <CardContent>
        {byClass.every((c) => c.items.length === 0) ? (
          <div className="flex min-h-[120px] flex-col items-center justify-center gap-2 rounded-xl border border-dashed border-slate-200 bg-slate-50/70 py-6 text-center">
            <span className="flex size-10 items-center justify-center rounded-xl bg-white text-slate-400 ring-1 ring-slate-200">
              <Plus className="size-4" />
            </span>
            <p className="text-sm text-slate-500">
              No subjects yet. Add the subjects each class is examined on, with their max marks.
            </p>
          </div>
        ) : (
          <div className="space-y-4">
            {byClass
              .filter((c) => c.items.length > 0)
              .map((c) => (
                <div key={c.id} className="space-y-2.5">
                  <p className="text-xs font-semibold uppercase tracking-wide text-slate-500">
                    {c.name}
                  </p>
                  <div className="flex flex-wrap gap-2">
                    {c.items.map((es) => (
                      <span
                        key={es.id}
                        className="group inline-flex items-center gap-1.5 rounded-xl border border-slate-200 bg-slate-50/80 py-1.5 pl-3 pr-1.5 text-sm font-medium text-slate-800"
                      >
                        {es.subjectName}
                        <Badge variant="outline" className="border-slate-200 px-1.5 py-0 text-[11px] font-normal text-slate-500">
                          /{es.maxMarks}
                        </Badge>
                        <button
                          type="button"
                          disabled={isPending}
                          onClick={() => remove(es.id, es.subjectName)}
                          aria-label={`Remove ${es.subjectName}`}
                          className="flex size-5 items-center justify-center rounded text-slate-400 transition-colors hover:bg-red-50 hover:text-red-600"
                        >
                          <X className="size-3.5" />
                        </button>
                      </span>
                    ))}
                  </div>
                </div>
              ))}
          </div>
        )}
      </CardContent>
    </Card>
  );
}
