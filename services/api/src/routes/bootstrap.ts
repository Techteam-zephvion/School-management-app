import { Hono } from 'hono';
import { zValidator } from '@hono/zod-validator';
import { z } from 'zod';
import { createDb } from '../db/client';
import { appUsers, schools, userRoles } from '../db/schema';
import { ApiError } from '../http/errors';
import { rateLimiter } from '../http/rate-limiter';
import type { AppBindings } from '../types';

const bootstrapSchema = z.object({
  school: z.object({
    name: z.string().min(2),
    code: z.string().min(2).max(24),
  }),
  admin: z.object({
    neonUserId: z.string().min(1),
    email: z.string().email(),
    displayName: z.string().min(2),
  }),
});

function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) {
    diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return diff === 0;
}

export const bootstrapRoutes = new Hono<AppBindings>();

bootstrapRoutes.use('*', rateLimiter({ maxRequests: 10, windowSeconds: 60, keyPrefix: 'rl:bootstrap' }));

bootstrapRoutes.post('/school', zValidator('json', bootstrapSchema), async (c) => {
  const token = c.req.header('x-bootstrap-token');
  const isProduction = c.env.APP_ENV === 'production';

  if (isProduction) {
    if (!c.env.BOOTSTRAP_TOKEN) {
      throw new ApiError(500, 'Bootstrap token is not configured on the server');
    }
    if (!token || !timingSafeEqual(token, c.env.BOOTSTRAP_TOKEN)) {
      throw new ApiError(403, 'Invalid or missing bootstrap token');
    }
  } else if (c.env.BOOTSTRAP_TOKEN) {
    // If a bootstrap token is configured in non-production, enforce it
    if (!token || !timingSafeEqual(token, c.env.BOOTSTRAP_TOKEN)) {
      throw new ApiError(403, 'Invalid or missing bootstrap token');
    }
  }

  const input = c.req.valid('json');
  const db = createDb(c.env.DATABASE_URL);
  const result = await db.transaction(async (tx) => {
    const [school] = await tx.insert(schools).values(input.school).returning();
    if (!school) throw new ApiError(500, 'Unable to create school');

    const [admin] = await tx
      .insert(appUsers)
      .values({
        schoolId: school.id,
        neonUserId: input.admin.neonUserId,
        email: input.admin.email,
        displayName: input.admin.displayName,
      })
      .returning();
    if (!admin) throw new ApiError(500, 'Unable to create admin');

    await tx.insert(userRoles).values({ userId: admin.id, role: 'admin' });
    return { school, admin: { ...admin, roles: ['admin'] } };
  });

  return c.json(result, 201);
});
