"use client";

import { ErrorBoundaryView } from "@/components/error-boundary-view";

export default function PlatformError({
  error,
  unstable_retry,
}: {
  error: Error & { digest?: string };
  unstable_retry: () => void;
}) {
  return <ErrorBoundaryView error={error} retry={unstable_retry} where="platform" />;
}
