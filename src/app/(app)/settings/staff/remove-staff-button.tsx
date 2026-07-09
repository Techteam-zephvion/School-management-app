"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Trash2, Loader2 } from "lucide-react";
import { removeStaffMember } from "@/lib/actions/staff";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
  DialogTrigger,
  DialogClose,
  DialogFooter,
} from "@/components/ui/dialog";

export function RemoveStaffButton({
  memberId,
  name,
}: {
  memberId: string;
  name: string;
}) {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [isPending, startTransition] = useTransition();

  function remove() {
    startTransition(async () => {
      const fd = new FormData();
      fd.set("memberId", memberId);
      const result = await removeStaffMember(undefined, fd);
      if (result?.error) {
        toast.error(result.error);
      } else {
        setOpen(false);
        toast.success(`${name} removed from staff.`);
        router.refresh();
      }
    });
  }

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button
          variant="outline"
          size="sm"
          className="gap-1.5 border-red-200 text-red-600 hover:bg-red-50 hover:text-red-700"
        >
          <Trash2 className="size-4" />
          Remove
        </Button>
      </DialogTrigger>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Remove {name}?</DialogTitle>
          <DialogDescription>
            This staff member will lose access to the school. Their profile and any
            associated data (classes, assignments, etc.) may be affected. This can&apos;t
            be undone.
          </DialogDescription>
        </DialogHeader>
        <DialogFooter className="gap-2 sm:gap-0">
          <DialogClose asChild>
            <Button variant="outline" disabled={isPending}>
              Cancel
            </Button>
          </DialogClose>
          <Button
            variant="destructive"
            onClick={remove}
            disabled={isPending}
            className="gap-2"
          >
            {isPending ? <Loader2 className="size-4 animate-spin" /> : <Trash2 className="size-4" />}
            Remove staff
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
