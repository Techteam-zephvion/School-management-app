"use client";

import { useEffect } from "react";
import { captureException } from "@/lib/monitoring";
import "./globals.css";

/**
 * Last-resort boundary: catches errors thrown by the root layout itself. It
 * replaces the whole document, so it must render its own <html>/<body> and can't
 * rely on the app shell or shared components.
 */
export default function GlobalError({
  error,
  unstable_retry,
}: {
  error: Error & { digest?: string };
  unstable_retry: () => void;
}) {
  useEffect(() => {
    captureException(error, { boundary: "global", digest: error.digest });
  }, [error]);

  return (
    <html lang="en" className="h-full antialiased">
      <body className="flex min-h-full items-center justify-center bg-background p-6 text-foreground">
        <div className="flex flex-col items-center gap-5 text-center">
          <div className="flex size-14 items-center justify-center rounded-2xl bg-destructive/10 text-2xl text-destructive">
            !
          </div>
          <div className="space-y-1.5">
            <h1 className="text-lg font-semibold tracking-tight">Something went wrong</h1>
            <p className="max-w-sm text-sm leading-relaxed text-muted-foreground">
              The app hit an unexpected error. Please try again in a moment.
            </p>
            {error.digest && (
              <p className="pt-1 font-mono text-xs text-muted-foreground/60">Ref: {error.digest}</p>
            )}
          </div>
          <button
            onClick={() => unstable_retry()}
            className="inline-flex h-9 items-center rounded-lg bg-primary px-4 text-sm font-medium text-primary-foreground transition-colors hover:bg-primary/90"
          >
            Try again
          </button>
        </div>
      </body>
    </html>
  );
}
