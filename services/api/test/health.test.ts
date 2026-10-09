import { describe, expect, it } from 'vitest';
import { createApp } from '../src/index';

describe('health route', () => {
  it('returns service status', async () => {
    const response = await createApp().request('/health', {}, {
      APP_ENV: 'test',
      CORS_ORIGIN: '*',
      DATABASE_URL: 'postgres://example',
      NEON_AUTH_URL: 'https://auth.example.test',
    });

    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toEqual({ ok: true, service: 'schoolic-api' });
  });
});
