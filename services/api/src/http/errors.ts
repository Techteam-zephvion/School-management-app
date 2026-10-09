import type { Context } from 'hono';

export class ApiError extends Error {
  constructor(
    public readonly status: 400 | 401 | 403 | 404 | 409 | 422 | 500,
    message: string,
  ) {
    super(message);
  }
}

export function fail(c: Context, error: unknown) {
  if (error instanceof ApiError) {
    return c.json({ error: error.message }, error.status);
  }

  console.error(error);
  return c.json({ error: 'Unexpected server error' }, 500);
}
