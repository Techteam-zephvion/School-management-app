"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Trash2, Loader2 } from "lucide-react";
import { deleteHomework } from "@/lib/actions/homework";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
  DialogTrigger,
  DialogFooter,
  DialogClose,
} from "@/components/ui/dialog";

export function DeleteHomeworkButton({ id, title }: { id: string; title: string }) {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [isPending, startTransition] = useTransition();

  function remove() {
    startTransition(async () => {
      const result = await deleteHomework(id);
      if (result?.error) {
        toast.error(result.error);
      } else {
        setOpen(false);
        toast.success("Homework deleted.");
        router.push("/homework");
      }
    });
  }

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button
          variant="outline"
          size="sm"
          className="gap-1.5 border-red-200/60 text-red-600 transition-all hover:border-red-300 hover:bg-red-50 hover:text-red-700"
        >
          <Trash2 className="size-4" />
          Delete
        </Button>
      </DialogTrigger>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>Delete homework?</DialogTitle>
          <DialogDescription>
            &ldquo;{title}&rdquo; and its attachment will be permanently removed. This can&apos;t be
            undone.
          </DialogDescription>
        </DialogHeader>
        <div className="flex items-start gap-3 rounded-xl border border-red-200/60 bg-red-50/60 p-3">
          <span className="flex size-7 shrink-0 items-center justify-center rounded-lg bg-red-100 text-red-600">
            <Trash2 className="size-3.5" />
          </span>
          <p className="text-xs text-red-700">
            This action is permanent and cannot be reversed. All data will be lost.
          </p>
        </div>
        <DialogFooter>
          <DialogClose asChild>
            <Button variant="outline" disabled={isPending} className="border-slate-200/80 text-slate-700 hover:bg-slate-50 hover:text-slate-900">
              Cancel
            </Button>
          </DialogClose>
          <Button variant="destructive" onClick={remove} disabled={isPending} className="gap-2">
            {isPending ? <Loader2 className="size-4 animate-spin" /> : <Trash2 className="size-4" />}
            Delete homework
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
