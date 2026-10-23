import { Hono } from 'hono';
import { zValidator } from '@hono/zod-validator';
import { z } from 'zod';
import { createDb } from '../db/client';
import { rateLimiter } from '../http/rate-limiter';
import { publicInquirySchema } from '../http/validation';
import { createSchoolRepository } from '../repositories/school-repository';
import type { AppBindings } from '../types';

export const publicRoutes = new Hono<AppBindings>();

// Rate limit public endpoints to protect against abuse/scraping
publicRoutes.use('*', rateLimiter({ maxRequests: 60, windowSeconds: 60 }));

// Public school profile for admission landing page
publicRoutes.get(
  '/schools/:code',
  zValidator('param', z.object({ code: z.string().trim().min(1) })),
  async (c) => {
    const { code } = c.req.valid('param');
    const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
    return c.json(await repo.getSchoolPublicProfile(code));
  },
);

// Public prospective student inquiry / admission application
publicRoutes.post('/inquiries', zValidator('json', publicInquirySchema), async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  return c.json(await repo.createPublicInquiry(c.req.valid('json')), 201);
});

publicRoutes.post('/admissions/apply', zValidator('json', publicInquirySchema), async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  return c.json(await repo.createPublicInquiry(c.req.valid('json')), 201);
});

// Public digital certificate verification
publicRoutes.get(
  '/certificates/verify/:code',
  zValidator('param', z.object({ code: z.string().trim().min(1) })),
  async (c) => {
    const { code } = c.req.valid('param');
    const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
    return c.json(await repo.verifyCertificatePublic(code));
  },
);
