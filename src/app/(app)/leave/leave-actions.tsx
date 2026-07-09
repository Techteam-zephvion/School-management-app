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
        className="gap-1 border-red-200 text-red-600 hover:bg-red-50 hover:text-red-700"
      >
        <X className="size-4" /> Reject
      </Button>
      <Button
        size="sm"
        disabled={isPending}
        onClick={() => review(true)}
        className="gap-1 bg-primary text-primary-foreground hover:bg-primary/80"
      >
        {isPending ? <Loader2 className="size-4 animate-spin" /> : <Check className="size-4" />} Approve
      </Button>
    </div>
  );
}
