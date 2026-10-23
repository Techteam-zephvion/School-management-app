import type { Context } from 'hono';

export class ApiError extends Error {
  constructor(
    public readonly status: 400 | 401 | 403 | 404 | 409 | 413 | 415 | 422 | 429 | 500 | 503 | 504,
    message: string,
  ) {
    super(message);
  }
}

export function fail(c: Context, error: unknown) {
  if (error instanceof ApiError) {
    return c.json({ error: error.message }, error.status);
  }

  console.error('Unexpected API error', error);
  if (error instanceof Error && 'cause' in error) {
    console.error('Unexpected API error cause', error.cause);
  }
  return c.json({ error: 'Unexpected server error' }, 500);
}
