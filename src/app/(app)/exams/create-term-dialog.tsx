"use client";

import { useActionState, useState } from "react";
import { toast } from "sonner";
import { Plus, Loader2 } from "lucide-react";
import { createTerm } from "@/lib/actions/exams";
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

export function CreateTermDialog() {
  const [open, setOpen] = useState(false);
  const [state, formAction, pending] = useActionState(
    async (prev: Awaited<ReturnType<typeof createTerm>>, fd: FormData) => {
      const result = await createTerm(prev, fd);
      if (!result?.error) {
        toast.success("Exam term created.");
        setOpen(false);
      }
      return result;
    },
    undefined
  );

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button className="gap-2 bg-[#10203f] text-white hover:bg-[#1b2d5e]">
          <Plus className="size-4" /> New term
        </Button>
      </DialogTrigger>
      <DialogContent className="rounded-2xl border-slate-200/80 shadow-xl shadow-slate-950/10">
        <DialogHeader>
          <DialogTitle className="text-xl font-bold tracking-tight text-slate-900">New exam term</DialogTitle>
          <DialogDescription className="text-slate-500">e.g. &ldquo;Term 1&rdquo;, &ldquo;Mid-term&rdquo;, &ldquo;Final&rdquo;.</DialogDescription>
        </DialogHeader>
        <form action={formAction} className="space-y-4">
          <div className="space-y-2">
            <Label htmlFor="name" className="text-xs font-semibold uppercase tracking-wide text-slate-500">
              Term name
            </Label>
            <Input id="name" name="name" placeholder="Term 1" required className="border-slate-200/80 focus-visible:ring-blue-500" />
          </div>
          {state?.error && (
            <p className="rounded-lg border border-red-100 bg-red-50/80 px-3 py-2 text-sm text-red-700">
              {state.error}
            </p>
          )}
          <DialogFooter>
            <Button type="submit" disabled={pending} className="gap-2 bg-[#10203f] text-white hover:bg-[#1b2d5e]">
              {pending && <Loader2 className="size-4 animate-spin" />}
              {pending ? "Creating…" : "Create term"}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
