"use client";

import { useTransition } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { toast } from "sonner";
import { Check, X, Loader2, CalendarX2 } from "lucide-react";
import { reviewLeave } from "@/lib/actions/leave";
import { Avatar, AvatarFallback } from "@/components/ui/avatar";

export type LeaveItem = { id: string; studentName: string; detail: string };

function initials(name: string) {
  return name.split(/\s+/).map((p) => p[0]).slice(0, 2).join("").toUpperCase() || "?";
}

export function PendingLeave({ items, canReview }: { items: LeaveItem[]; canReview: boolean }) {
  const router = useRouter();
  const [pending, start] = useTransition();

  function act(id: string, approve: boolean) {
    start(async () => {
      const res = await reviewLeave(id, approve);
      if (res?.error) toast.error(res.error);
      else {
        toast.success(approve ? "Leave approved." : "Leave declined.");
        router.refresh();
      }
    });
  }

  if (items.length === 0) {
    return (
      <div className="flex flex-col items-center gap-2 py-8 text-center">
        <span className="flex size-11 items-center justify-center rounded-2xl bg-muted/60">
          <CalendarX2 className="size-5 text-muted-foreground/70" />
        </span>
        <p className="text-sm text-muted-foreground">No leave requests waiting.</p>
      </div>
    );
  }

  return (
    <div className="space-y-2">
      {items.map((l) => (
        <div key={l.id} className="flex items-center gap-3 rounded-xl border border-border/50 px-3 py-2.5">
          <Avatar className="size-9">
            <AvatarFallback>{initials(l.studentName)}</AvatarFallback>
          </Avatar>
          <div className="min-w-0 flex-1">
            <p className="truncate text-sm font-medium">{l.studentName}</p>
            <p className="truncate text-xs text-muted-foreground">{l.detail}</p>
          </div>
          {canReview ? (
            <div className="flex items-center gap-1.5">
              <button
                type="button"
                disabled={pending}
                onClick={() => act(l.id, false)}
                aria-label="Decline leave"
                className="flex size-8 items-center justify-center rounded-lg border border-border/60 text-destructive transition-colors hover:bg-destructive/10 disabled:opacity-50"
              >
                {pending ? <Loader2 className="size-4 animate-spin" /> : <X className="size-4" />}
              </button>
              <button
                type="button"
                disabled={pending}
                onClick={() => act(l.id, true)}
                aria-label="Approve leave"
                className="flex size-8 items-center justify-center rounded-lg border border-success/30 bg-success/10 text-success transition-colors hover:bg-success/20 disabled:opacity-50"
              >
                {pending ? <Loader2 className="size-4 animate-spin" /> : <Check className="size-4" />}
              </button>
            </div>
          ) : (
            <Link href="/leave" className="text-xs font-medium text-primary hover:underline">
              Review
            </Link>
          )}
        </div>
      ))}
    </div>
  );
}
