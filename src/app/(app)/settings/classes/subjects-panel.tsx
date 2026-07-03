"use client";

import { useActionState, useState, useTransition } from "react";
import { toast } from "sonner";
import { Plus, X } from "lucide-react";
import { createSubject, deleteSubject } from "@/lib/actions/academic";
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
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
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

  function remove(id: string, name: string) {
    startTransition(async () => {
      const result = await deleteSubject(id);
      if (result?.error) toast.error(result.error);
      else toast.success(`Removed ${name}.`);
    });
  }

  return (
    <Card>
      <CardHeader className="flex-row items-start justify-between space-y-0">
        <div>
          <CardTitle>Subjects</CardTitle>
          <CardDescription>
            The subjects taught across your school.
          </CardDescription>
        </div>
        <Dialog open={open} onOpenChange={setOpen}>
          <DialogTrigger asChild>
            <Button variant="outline" className="gap-2">
              <Plus className="size-4" /> Add subject
            </Button>
          </DialogTrigger>
          <DialogContent>
            <DialogHeader>
              <DialogTitle>Add a subject</DialogTitle>
            </DialogHeader>
            <form action={formAction} className="space-y-4">
              <div className="space-y-2">
                <Label htmlFor="subject-name">Name</Label>
                <Input id="subject-name" name="name" placeholder="Mathematics" required />
              </div>
              <div className="space-y-2">
                <Label htmlFor="subject-code">Code (optional)</Label>
                <Input id="subject-code" name="code" placeholder="MATH" />
              </div>
              {state?.error && (
                <p className="text-sm text-destructive">{state.error}</p>
              )}
              <DialogFooter>
                <Button type="submit" disabled={pending}>
                  {pending ? "Adding…" : "Add subject"}
                </Button>
              </DialogFooter>
            </form>
          </DialogContent>
        </Dialog>
      </CardHeader>
      <CardContent>
        {subjects.length === 0 ? (
          <p className="py-2 text-sm text-muted-foreground">
            No subjects yet. Add Mathematics, Science, English…
          </p>
        ) : (
          <div className="flex flex-wrap gap-2">
            {subjects.map((s) => (
              <span
                key={s.id}
                className="group inline-flex items-center gap-1.5 rounded-full border border-border bg-secondary/60 py-1 pl-3 pr-1.5 text-sm font-medium"
              >
                {s.name}
                {s.code ? (
                  <span className="text-xs text-muted-foreground">{s.code}</span>
                ) : null}
                <button
                  type="button"
                  disabled={isPending}
                  onClick={() => remove(s.id, s.name)}
                  aria-label={`Remove ${s.name}`}
                  className="flex size-5 items-center justify-center rounded-full text-muted-foreground transition-colors hover:bg-destructive/10 hover:text-destructive"
                >
                  <X className="size-3.5" />
                </button>
              </span>
            ))}
          </div>
        )}
      </CardContent>
    </Card>
  );
}
