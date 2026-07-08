"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Send, Undo2, Trash2, Loader2 } from "lucide-react";
import { setTermPublished, deleteTerm } from "@/lib/actions/exams";
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

export function TermAdminBar({
  termId,
  isPublished,
  termName,
}: {
  termId: string;
  isPublished: boolean;
  termName: string;
}) {
  const router = useRouter();
  const [isPending, startTransition] = useTransition();
  const [pubOpen, setPubOpen] = useState(false);
  const [delOpen, setDelOpen] = useState(false);

  function togglePublish() {
    startTransition(async () => {
      const result = await setTermPublished(termId, !isPublished);
      if (result?.error) toast.error(result.error);
      else {
        setPubOpen(false);
        toast.success(isPublished ? "Results unpublished." : "Results published to parents.");
      }
    });
  }

  function remove() {
    startTransition(async () => {
      const result = await deleteTerm(termId);
      if (result?.error) toast.error(result.error);
      else {
        toast.success("Term deleted.");
        router.push("/exams");
      }
    });
  }

  return (
    <div className="flex items-center gap-2">
      {/* publish / unpublish */}
      <Dialog open={pubOpen} onOpenChange={setPubOpen}>
        <DialogTrigger asChild>
          {isPublished ? (
            <Button variant="outline" size="sm" className="gap-1.5 border-slate-200/80 text-slate-700 hover:bg-slate-50 hover:text-slate-900">
              <Undo2 className="size-4" /> Unpublish
            </Button>
          ) : (
            <Button size="sm" className="gap-1.5 bg-[#10203f] text-white hover:bg-[#1b2d5e]">
              <Send className="size-4" /> Publish results
            </Button>
          )}
        </DialogTrigger>
        <DialogContent className="rounded-2xl border-slate-200/80 shadow-xl shadow-slate-950/10">
          <DialogHeader>
            <DialogTitle className="text-xl font-bold tracking-tight text-slate-900">
              {isPublished ? "Unpublish results?" : "Publish results?"}
            </DialogTitle>
            <DialogDescription className="text-slate-500">
              {isPublished
                ? `Parents will no longer see results for "${termName}".`
                : `Parents will be able to see their child's marks and grade for "${termName}".`}
            </DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <DialogClose asChild>
              <Button variant="outline" disabled={isPending} className="border-slate-200/80 text-slate-700">
                Cancel
              </Button>
            </DialogClose>
            <Button
              onClick={togglePublish}
              disabled={isPending}
              className={`gap-2 ${isPublished ? "bg-slate-700 text-white hover:bg-slate-800" : "bg-[#10203f] text-white hover:bg-[#1b2d5e]"}`}
            >
              {isPending ? <Loader2 className="size-4 animate-spin" /> : <Send className="size-4" />}
              {isPublished ? "Unpublish" : "Publish"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* delete */}
      <Dialog open={delOpen} onOpenChange={setDelOpen}>
        <DialogTrigger asChild>
          <Button
            variant="outline"
            size="sm"
            aria-label="Delete term"
            className="gap-1.5 border-red-200 text-red-600 transition-colors hover:border-red-300 hover:bg-red-50 hover:text-red-700"
          >
            <Trash2 className="size-4" />
          </Button>
        </DialogTrigger>
        <DialogContent className="rounded-2xl border-slate-200/80 shadow-xl shadow-slate-950/10">
          <DialogHeader>
            <DialogTitle className="text-xl font-bold tracking-tight text-slate-900">
              Delete exam term?
            </DialogTitle>
            <DialogDescription className="text-slate-500">
              &ldquo;{termName}&rdquo; and all its subjects and marks will be permanently removed.
              This can&apos;t be undone.
            </DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <DialogClose asChild>
              <Button variant="outline" disabled={isPending} className="border-slate-200/80 text-slate-700">
                Cancel
              </Button>
            </DialogClose>
            <Button
              variant="destructive"
              onClick={remove}
              disabled={isPending}
              className="gap-2 bg-red-600 text-white hover:bg-red-700"
            >
              {isPending ? <Loader2 className="size-4 animate-spin" /> : <Trash2 className="size-4" />}
              Delete term
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
