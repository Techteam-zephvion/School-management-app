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
            <Button variant="outline" size="sm" className="gap-1.5">
              <Undo2 className="size-4" /> Unpublish
            </Button>
          ) : (
            <Button size="sm" className="gap-1.5">
              <Send className="size-4" /> Publish results
            </Button>
          )}
        </DialogTrigger>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{isPublished ? "Unpublish results?" : "Publish results?"}</DialogTitle>
            <DialogDescription>
              {isPublished
                ? `Parents will no longer see results for “${termName}”.`
                : `Parents will be able to see their child's marks and grade for “${termName}”.`}
            </DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <DialogClose asChild>
              <Button variant="outline" disabled={isPending}>
                Cancel
              </Button>
            </DialogClose>
            <Button onClick={togglePublish} disabled={isPending} className="gap-2">
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
            className="gap-1.5 border-destructive/30 text-destructive transition-all hover:border-destructive/50 hover:bg-destructive/10 hover:text-destructive"
          >
            <Trash2 className="size-4" />
          </Button>
        </DialogTrigger>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Delete exam term?</DialogTitle>
            <DialogDescription>
              &ldquo;{termName}&rdquo; and all its subjects and marks will be permanently removed.
              This can&apos;t be undone.
            </DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <DialogClose asChild>
              <Button variant="outline" disabled={isPending}>
                Cancel
              </Button>
            </DialogClose>
            <Button variant="destructive" onClick={remove} disabled={isPending} className="gap-2">
              {isPending ? <Loader2 className="size-4 animate-spin" /> : <Trash2 className="size-4" />}
              Delete term
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
