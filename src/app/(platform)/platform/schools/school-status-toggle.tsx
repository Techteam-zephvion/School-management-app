"use client";

import { useState, useTransition } from "react";
import { toast } from "sonner";
import { Ban, Undo2, Loader2 } from "lucide-react";
import { setSchoolStatus } from "@/lib/actions/platform";
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

export function SchoolStatusToggle({ schoolId, suspended, name }: { schoolId: string; suspended: boolean; name: string }) {
  const [open, setOpen] = useState(false);
  const [isPending, startTransition] = useTransition();

  function toggle() {
    startTransition(async () => {
      const result = await setSchoolStatus(schoolId, suspended ? "active" : "suspended");
      if (result?.error) toast.error(result.error);
      else {
        setOpen(false);
        toast.success(suspended ? "School reactivated." : "School suspended.");
      }
    });
  }

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button
          variant="outline"
          size="sm"
          className={suspended ? "gap-1.5" : "gap-1.5 border-destructive/30 text-destructive hover:bg-destructive/10 hover:text-destructive"}
        >
          {suspended ? <Undo2 className="size-4" /> : <Ban className="size-4" />}
          {suspended ? "Reactivate" : "Suspend"}
        </Button>
      </DialogTrigger>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{suspended ? "Reactivate school?" : "Suspend school?"}</DialogTitle>
          <DialogDescription>
            {suspended
              ? `“${name}” will be marked active again.`
              : `“${name}” will be marked suspended. Use this to pause an account.`}
          </DialogDescription>
        </DialogHeader>
        <DialogFooter>
          <DialogClose asChild>
            <Button variant="outline" disabled={isPending}>Cancel</Button>
          </DialogClose>
          <Button
            variant={suspended ? "default" : "destructive"}
            onClick={toggle}
            disabled={isPending}
            className="gap-2"
          >
            {isPending && <Loader2 className="size-4 animate-spin" />}
            {suspended ? "Reactivate" : "Suspend"}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
