import { zValidator } from '@hono/zod-validator';
import { Hono } from 'hono';
import { createDb } from '../db/client';
import { requireRole } from '../http/auth';
import { portalStudentQuerySchema } from '../http/validation';
import { createSchoolRepository } from '../repositories/school-repository';
import type { AppBindings } from '../types';

export const portalRoutes = new Hono<AppBindings>();

portalRoutes.use('*', async (c, next) => {
  requireRole(c.get('authUser'), ['student', 'parent']);
  await next();
});

portalRoutes.get('/profile', async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  return c.json(await repo.portalProfile(c.get('authUser')));
});

portalRoutes.get('/announcements', zValidator('query', portalStudentQuerySchema), async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  return c.json(await repo.portalAnnouncements(c.get('authUser'), c.req.valid('query').studentId));
});

portalRoutes.get('/attendance', zValidator('query', portalStudentQuerySchema), async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  return c.json(await repo.portalAttendance(c.get('authUser'), c.req.valid('query').studentId));
});

portalRoutes.get('/timetable', zValidator('query', portalStudentQuerySchema), async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  return c.json(await repo.portalTimetable(c.get('authUser'), c.req.valid('query').studentId));
});
