import { describe, expect, it, beforeEach } from 'vitest';
import { Hono } from 'hono';
import { rateLimiter, clearRateLimitStore } from '../src/http/rate-limiter';
import type { AppBindings } from '../src/types';

describe('Phase 9 — Rate Limiter Middleware', () => {
  beforeEach(() => {
    clearRateLimitStore();
  });

  it('allows requests within the configured threshold and sets headers', async () => {
    const app = new Hono<AppBindings>();
    app.use('/test', rateLimiter({ maxRequests: 3, windowSeconds: 60, keyPrefix: 'test-rl' }));
    app.get('/test', (c) => c.json({ ok: true }));

    // Request 1
    const res1 = await app.request('/test', { headers: { 'cf-connecting-ip': '1.2.3.4' } });
    expect(res1.status).toBe(200);
    expect(res1.headers.get('X-RateLimit-Limit')).toBe('3');
    expect(res1.headers.get('X-RateLimit-Remaining')).toBe('2');

    // Request 2
    const res2 = await app.request('/test', { headers: { 'cf-connecting-ip': '1.2.3.4' } });
    expect(res2.status).toBe(200);
    expect(res2.headers.get('X-RateLimit-Remaining')).toBe('1');

    // Request 3
    const res3 = await app.request('/test', { headers: { 'cf-connecting-ip': '1.2.3.4' } });
    expect(res3.status).toBe(200);
    expect(res3.headers.get('X-RateLimit-Remaining')).toBe('0');
  });

  it('rejects requests exceeding the threshold with 429 and Retry-After', async () => {
    const app = new Hono<AppBindings>();
    app.use('/test', rateLimiter({ maxRequests: 2, windowSeconds: 30, keyPrefix: 'test-rl' }));
    app.get('/test', (c) => c.json({ ok: true }));

    await app.request('/test', { headers: { 'cf-connecting-ip': '5.6.7.8' } });
    await app.request('/test', { headers: { 'cf-connecting-ip': '5.6.7.8' } });

    // Request 3 exceeds
    const res3 = await app.request('/test', { headers: { 'cf-connecting-ip': '5.6.7.8' } });
    expect(res3.status).toBe(429);
    expect(res3.headers.get('Retry-After')).toBeDefined();

    const body = (await res3.json()) as any;
    expect(body.error).toContain('Too many requests');
    expect(body.code).toBe('RATE_LIMIT_EXCEEDED');
    expect(body.retryAfterSeconds).toBeGreaterThan(0);
  });
});
