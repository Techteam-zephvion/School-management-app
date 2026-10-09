import { Hono } from 'hono';
import { zValidator } from '@hono/zod-validator';
import { z } from 'zod';
import { createDb } from '../db/client';
import { appUsers, schools, userRoles } from '../db/schema';
import { ApiError } from '../http/errors';
import type { AppBindings } from '../types';

const bootstrapSchema = z.object({
  school: z.object({
    name: z.string().min(2),
    code: z.string().min(2).max(24),
  }),
  admin: z.object({
    neonUserId: z.string().min(1),
    email: z.email(),
    displayName: z.string().min(2),
  }),
});

export const bootstrapRoutes = new Hono<AppBindings>();

bootstrapRoutes.post('/school', zValidator('json', bootstrapSchema), async (c) => {
  const token = c.req.header('x-bootstrap-token');
  if (c.env.APP_ENV === 'production' && (!c.env.BOOTSTRAP_TOKEN || token !== c.env.BOOTSTRAP_TOKEN)) {
    throw new ApiError(403, 'Bootstrap token required');
  }

  const input = c.req.valid('json');
  const db = createDb(c.env.DATABASE_URL);
  const [school] = await db.insert(schools).values(input.school).returning();
  if (!school) throw new ApiError(500, 'Unable to create school');

  const [admin] = await db
    .insert(appUsers)
    .values({
      schoolId: school.id,
      neonUserId: input.admin.neonUserId,
      email: input.admin.email,
      displayName: input.admin.displayName,
    })
    .returning();
  if (!admin) throw new ApiError(500, 'Unable to create admin');

  await db.insert(userRoles).values({ userId: admin.id, role: 'admin' });
  return c.json({ school, admin: { ...admin, roles: ['admin'] } }, 201);
});
