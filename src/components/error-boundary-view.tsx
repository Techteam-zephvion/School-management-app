"use client";

import { useEffect } from "react";
import { AlertTriangle, RotateCw } from "lucide-react";
import { captureException } from "@/lib/monitoring";
import { Button } from "@/components/ui/button";

/**
 * Shared fallback UI for route-segment error boundaries. Reports the error once
 * on mount and offers a retry that re-fetches and re-renders the segment.
 */
export function ErrorBoundaryView({
  error,
  retry,
  where,
}: {
  error: Error & { digest?: string };
  retry: () => void;
  where: string;
}) {
  useEffect(() => {
    captureException(error, { boundary: where, digest: error.digest });
  }, [error, where]);

  return (
    <div className="flex min-h-[60vh] flex-col items-center justify-center gap-5 px-6 text-center">
      <span className="flex size-14 items-center justify-center rounded-2xl bg-destructive/10 text-destructive">
        <AlertTriangle className="size-7" />
      </span>
      <div className="space-y-1.5">
        <h1 className="text-lg font-semibold tracking-tight">Something went wrong</h1>
        <p className="max-w-sm text-sm leading-relaxed text-muted-foreground">
          This section couldn&apos;t load. It&apos;s usually temporary — try again, and if it keeps
          happening, let your administrator know.
        </p>
        {error.digest && (
          <p className="pt-1 font-mono text-xs text-muted-foreground/60">Ref: {error.digest}</p>
        )}
      </div>
      <Button onClick={retry} className="gap-2">
        <RotateCw className="size-4" /> Try again
      </Button>
    </div>
  );
}
