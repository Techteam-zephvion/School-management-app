import type { MiddlewareHandler } from 'hono';
import type { AppBindings } from '../types';

interface RateLimitRecord {
  count: number;
  resetAt: number;
}

const memoryRateLimitStore = new Map<string, RateLimitRecord>();

export interface RateLimiterOptions {
  maxRequests: number;
  windowSeconds: number;
  keyPrefix?: string;
  keyGenerator?: (c: any) => string;
}

/**
 * High-performance sliding/fixed window rate limiter middleware.
 * Automatically cleans up expired windows to prevent memory exhaustion.
 */
export function rateLimiter(options: RateLimiterOptions): MiddlewareHandler<AppBindings> {
  const { maxRequests, windowSeconds, keyPrefix = 'rl', keyGenerator } = options;

  return async (c, next) => {
    // If running in test and disabled, pass through
    if (c.env?.APP_ENV === 'test' && c.req.header('x-skip-rate-limit') === 'true') {
      return next();
    }

    const clientIp =
      c.req.header('cf-connecting-ip') ||
      c.req.header('x-forwarded-for')?.split(',')[0]?.trim() ||
      '127.0.0.1';

    const customKey = keyGenerator ? keyGenerator(c) : clientIp;
    const key = `${keyPrefix}:${customKey}`;
    const now = Date.now();
    const windowMs = windowSeconds * 1000;

    // Check Cloudflare native Rate Limiting binding if configured (Audit Bug #6)
    const cfRateLimiter = (c.env as any)?.RATE_LIMITER;
    if (cfRateLimiter?.limit) {
      try {
        const { success } = await cfRateLimiter.limit({ key });
        if (!success) {
          c.header('Retry-After', String(windowSeconds));
          return c.json(
            {
              error: 'Too many requests. Please slow down.',
              code: 'RATE_LIMIT_EXCEEDED',
              retryAfterSeconds: windowSeconds,
            },
            429,
          );
        }
        return next();
      } catch {
        // Fall back to bounded in-memory sliding window
      }
    }

    // Edge Memory Protection: enforce size ceiling and evict expired records
    const MAX_STORE_SIZE = 5000;
    if (memoryRateLimitStore.size >= MAX_STORE_SIZE) {
      for (const [k, v] of memoryRateLimitStore.entries()) {
        if (now >= v.resetAt) {
          memoryRateLimitStore.delete(k);
        }
      }
      if (memoryRateLimitStore.size >= MAX_STORE_SIZE) {
        let toRemove = memoryRateLimitStore.size - Math.floor(MAX_STORE_SIZE * 0.8);
        for (const k of memoryRateLimitStore.keys()) {
          if (toRemove-- <= 0) break;
          memoryRateLimitStore.delete(k);
        }
      }
    }

    let record = memoryRateLimitStore.get(key);
    if (!record || now >= record.resetAt) {
      record = {
        count: 1,
        resetAt: now + windowMs,
      };
      memoryRateLimitStore.set(key, record);
    } else {
      record.count += 1;
    }

    const remaining = Math.max(0, maxRequests - record.count);
    const retryAfter = Math.ceil((record.resetAt - now) / 1000);

    c.header('X-RateLimit-Limit', String(maxRequests));
    c.header('X-RateLimit-Remaining', String(remaining));
    c.header('X-RateLimit-Reset', String(Math.ceil(record.resetAt / 1000)));

    if (record.count > maxRequests) {
      c.header('Retry-After', String(retryAfter));
      return c.json(
        {
          error: 'Too many requests. Please slow down.',
          code: 'RATE_LIMIT_EXCEEDED',
          retryAfterSeconds: retryAfter,
        },
        429,
      );
    }

    await next();
  };
}

export function clearRateLimitStore(): void {
  memoryRateLimitStore.clear();
}
