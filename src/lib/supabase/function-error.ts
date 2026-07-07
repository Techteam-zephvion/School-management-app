type FunctionErrorContext = {
  clone?: () => FunctionErrorContext;
  json?: () => Promise<unknown>;
  text?: () => Promise<string>;
};

type FunctionErrorLike = {
  context?: FunctionErrorContext;
  message?: string;
};

function errorFromPayload(payload: unknown): string | null {
  if (!payload || typeof payload !== "object") return null;
  const value = (payload as { error?: unknown }).error;
  return typeof value === "string" && value.length > 0 ? value : null;
}

export async function functionErrorMessage(
  data: unknown,
  error: unknown,
  fallback: string
): Promise<string | null> {
  const dataError = errorFromPayload(data);
  if (dataError) return dataError;
  if (!error) return null;

  const fnError = error as FunctionErrorLike;
  const context = fnError.context;
  if (context) {
    const readableContext = context.clone?.() ?? context;
    try {
      const body = await readableContext.json?.();
      const bodyError = errorFromPayload(body);
      if (bodyError) return bodyError;
    } catch {
      // Fall through to text/message below.
    }

    const textContext = context.clone?.() ?? context;
    try {
      const text = await textContext.text?.();
      if (text) return text;
    } catch {
      // Fall through to the Supabase wrapper message.
    }
  }

  return fnError.message ?? fallback;
}
