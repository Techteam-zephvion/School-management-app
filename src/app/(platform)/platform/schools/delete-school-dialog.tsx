"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Trash2, Loader2, AlertTriangle } from "lucide-react";
import { deleteSchool } from "@/lib/actions/platform";
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
  DialogClose,
} from "@/components/ui/dialog";

export function DeleteSchoolDialog({
  schoolId,
  name,
  redirectAfter,
}: {
  schoolId: string;
  name: string;
  redirectAfter?: boolean;
}) {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [confirm, setConfirm] = useState("");
  const [isPending, startTransition] = useTransition();

  function remove() {
    startTransition(async () => {
      const result = await deleteSchool(schoolId, confirm);
      if (result?.error) {
        toast.error(result.error);
      } else {
        setOpen(false);
        toast.success(`“${name}” deleted.`);
        if (redirectAfter) router.push("/platform/schools");
        else router.refresh();
      }
    });
  }

  return (
    <Dialog
      open={open}
      onOpenChange={(o) => {
        setOpen(o);
        if (!o) setConfirm("");
      }}
    >
      <DialogTrigger asChild>
        <Button
          variant="outline"
          size="sm"
          className="gap-1.5 border-destructive/30 text-destructive hover:border-destructive/50 hover:bg-destructive/10 hover:text-destructive"
        >
          <Trash2 className="size-4" /> Delete
        </Button>
      </DialogTrigger>
      <DialogContent>
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2">
            <span className="flex size-8 items-center justify-center rounded-lg bg-destructive/10 text-destructive">
              <AlertTriangle className="size-4" />
            </span>
            Delete this school?
          </DialogTitle>
          <DialogDescription>
            This permanently removes <span className="font-semibold text-foreground">{name}</span> and{" "}
            <span className="font-medium">all of its data</span> — students, staff, attendance, marks,
            fees, messages and more. This cannot be undone.
          </DialogDescription>
        </DialogHeader>
        <div className="space-y-2">
          <Label htmlFor="confirm-name" className="text-sm font-medium text-foreground">
            Type <span className="font-semibold">{name}</span> to confirm
          </Label>
          <Input
            id="confirm-name"
            value={confirm}
            onChange={(e) => setConfirm(e.target.value)}
            placeholder={name}
            autoComplete="off"
            className="rounded-lg"
          />
        </div>
        <DialogFooter>
          <DialogClose asChild>
            <Button variant="outline" disabled={isPending}>
              Cancel
            </Button>
          </DialogClose>
          <Button
            variant="destructive"
            onClick={remove}
            disabled={isPending || confirm.trim() !== name}
            className="gap-2"
          >
            {isPending ? <Loader2 className="size-4 animate-spin" /> : <Trash2 className="size-4" />}
            Delete permanently
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
