"use client";

import { useActionState, useState, useTransition } from "react";
import { toast } from "sonner";
import { Plus, X, Trash2, BookOpen } from "lucide-react";
import { createSubject, deleteSubject } from "@/lib/actions/academic";
import { Card, CardContent } from "@/components/ui/card";
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

type Subject = { id: string; name: string; code: string | null };

export function SubjectsPanel({ subjects }: { subjects: Subject[] }) {
  const [open, setOpen] = useState(false);
  const [isPending, startTransition] = useTransition();

  const [state, formAction, pending] = useActionState(
    async (prev: Awaited<ReturnType<typeof createSubject>>, fd: FormData) => {
      const result = await createSubject(prev, fd);
      if (!result?.error) {
        toast.success("Subject added.");
        setOpen(false);
      }
      return result;
    },
    undefined
  );

  const [removingId, setRemovingId] = useState<string | null>(null);

  function confirmRemove() {
    if (!removingId) return;
    const subject = subjects.find((s) => s.id === removingId);
    startTransition(async () => {
      const result = await deleteSubject(removingId);
      if (result?.error) toast.error(result.error);
      else toast.success(`Removed ${subject?.name}.`);
      setRemovingId(null);
    });
  }

  return (
    <Card className="overflow-hidden border border-slate-200/80 bg-white shadow-sm shadow-slate-950/5 ring-1 ring-slate-900/[0.02]">
      {/* Card header */}
      <div className="flex flex-wrap items-start justify-between gap-3 border-b border-slate-100 px-5 py-4">
        <div className="flex items-center gap-3">
          <span className="flex size-9 items-center justify-center rounded-xl bg-blue-50 text-blue-700 ring-1 ring-blue-100">
            <BookOpen className="size-4.5" />
          </span>
          <div>
            <h2 className="text-base font-semibold text-slate-900">Subjects</h2>
            <p className="text-xs text-slate-500">The subjects taught across your school.</p>
          </div>
        </div>
        <Dialog open={open} onOpenChange={setOpen}>
          <DialogTrigger asChild>
            <Button className="gap-2 bg-primary text-primary-foreground hover:bg-primary/80">
              <Plus className="size-4" /> Add subject
            </Button>
          </DialogTrigger>
          <DialogContent className="sm:max-w-lg">
            <DialogHeader>
              <div className="flex items-center gap-3">
                <span className="flex size-9 shrink-0 items-center justify-center rounded-xl bg-blue-50 text-blue-700 ring-1 ring-blue-100">
                  <BookOpen className="size-4.5" />
                </span>
                <div>
                  <DialogTitle>Add a subject</DialogTitle>
                  <DialogDescription>Create a subject that can be mapped to classes.</DialogDescription>
                </div>
              </div>
            </DialogHeader>
            <form action={formAction} className="space-y-5">
              <div className="space-y-2">
                <Label htmlFor="subject-name" className="text-xs font-semibold text-slate-600">Name</Label>
                <Input id="subject-name" name="name" placeholder="Mathematics" required />
              </div>
              <div className="space-y-2">
                <Label htmlFor="subject-code" className="text-xs font-semibold text-slate-600">Code (optional)</Label>
                <Input id="subject-code" name="code" placeholder="MATH" />
              </div>
              {state?.error && (
                <div className="rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
                  {state.error}
                </div>
              )}
              <DialogFooter className="gap-2 sm:gap-0">
                <Button type="submit" disabled={pending} className="gap-2 bg-primary text-primary-foreground hover:bg-primary/80">
                  {pending ? "Adding…" : "Add subject"}
                </Button>
              </DialogFooter>
            </form>
          </DialogContent>
        </Dialog>
      </div>

      <CardContent className="px-5 py-5">
        {subjects.length === 0 ? (
          <div className="flex flex-col items-center gap-4 py-8 text-center">
            <span className="flex size-12 items-center justify-center rounded-2xl bg-slate-50 text-slate-400 ring-1 ring-slate-200">
              <BookOpen className="size-5" />
            </span>
            <div>
              <p className="text-sm font-medium text-slate-700">No subjects yet</p>
              <p className="mt-0.5 text-xs text-slate-500">Add Mathematics, Science, English…</p>
            </div>
          </div>
        ) : (
          <div className="flex flex-wrap gap-2">
            {subjects.map((s) => (
              <span
                key={s.id}
                className="group inline-flex items-center gap-1.5 rounded-lg border border-slate-200 bg-white py-1 pl-3 pr-1.5 text-sm font-medium shadow-sm"
              >
                {s.name}
                {s.code ? (
                  <span className="text-xs text-slate-400">{s.code}</span>
                ) : null}
                <button
                  type="button"
                  onClick={() => setRemovingId(s.id)}
                  aria-label={`Remove ${s.name}`}
                  className="flex size-5 items-center justify-center rounded text-slate-400 transition-colors hover:bg-red-50 hover:text-red-600"
                >
                  <X className="size-3.5" />
                </button>
              </span>
            ))}
          </div>
        )}
      </CardContent>

      {/* Delete confirmation dialog */}
      <Dialog open={removingId !== null} onOpenChange={(o) => !o && setRemovingId(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Delete subject?</DialogTitle>
            <DialogDescription>
              &ldquo;{subjects.find((s) => s.id === removingId)?.name}&rdquo; will be removed from the school and
              unlinked from all classes. This can&apos;t be undone.
            </DialogDescription>
          </DialogHeader>
          <DialogFooter className="gap-2 sm:gap-0">
            <Button variant="outline" onClick={() => setRemovingId(null)} disabled={isPending}>
              Cancel
            </Button>
            <Button variant="destructive" onClick={confirmRemove} disabled={isPending} className="gap-2">
              <Trash2 className="size-4" /> Delete subject
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </Card>
  );
}
