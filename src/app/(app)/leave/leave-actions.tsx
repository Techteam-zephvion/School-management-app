"use client";

import { useTransition } from "react";
import { toast } from "sonner";
import { Check, X, Loader2 } from "lucide-react";
import { reviewLeave } from "@/lib/actions/leave";
import { Button } from "@/components/ui/button";

export function LeaveActions({ id, student }: { id: string; student: string }) {
  const [isPending, startTransition] = useTransition();

  function review(approve: boolean) {
    startTransition(async () => {
      const result = await reviewLeave(id, approve);
      if (result?.error) toast.error(result.error);
      else toast.success(approve ? `Approved — ${student} marked excused.` : "Request rejected.");
    });
  }

  return (
    <div className="flex items-center gap-1.5">
      <Button
        size="sm"
        variant="outline"
        disabled={isPending}
        onClick={() => review(false)}
        className="gap-1 border-destructive/30 text-destructive hover:bg-destructive/10 hover:text-destructive"
      >
        <X className="size-4" /> Reject
      </Button>
      <Button size="sm" disabled={isPending} onClick={() => review(true)} className="gap-1">
        {isPending ? <Loader2 className="size-4 animate-spin" /> : <Check className="size-4" />} Approve
      </Button>
    </div>
  );
}
