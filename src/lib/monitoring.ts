/**
 * Error monitoring seam. Today it emits a single structured line that is easy to
 * grep in server logs (and shows in the browser console on the client). When a
 * real provider is added, forward from the one place below — every call site
 * (error boundaries, server actions) already routes through `captureException`.
 *
 * To wire Sentry later: `npm i @sentry/nextjs`, set NEXT_PUBLIC_SENTRY_DSN, and
 * call `Sentry.captureException(error, { extra: context })` inside the function.
 */

export type ErrorContext = Record<string, unknown>;

export function captureException(error: unknown, context: ErrorContext = {}): void {
  const err = error instanceof Error ? error : new Error(String(error));
  const payload = {
    level: "error" as const,
    ts: new Date().toISOString(),
    name: err.name,
    message: err.message,
    // Server Component errors carry a `digest` that matches the server log line.
    digest: (err as { digest?: string }).digest,
    where: typeof window === "undefined" ? "server" : "client",
    ...context,
  };

  // Structured, single-line so log tooling can parse it.
  console.error("[monitor]", JSON.stringify(payload), err.stack ?? "");
}
