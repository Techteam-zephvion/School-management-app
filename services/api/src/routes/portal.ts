import { zValidator } from '@hono/zod-validator';
import { Hono } from 'hono';
import { createDb } from '../db/client';
import { requireRole } from '../http/auth';
import { portalStudentQuerySchema, submitHomeworkSchema } from '../http/validation';
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

portalRoutes.get('/homework', zValidator('query', portalStudentQuerySchema), async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  return c.json(await repo.portalHomework(c.get('authUser'), c.req.valid('query').studentId));
});

portalRoutes.post('/homework/:assignmentId/submit', zValidator('json', submitHomeworkSchema), async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  const assignmentId = c.req.param('assignmentId');
  return c.json(await repo.portalSubmitHomework(c.get('authUser'), assignmentId, c.req.valid('json')), 201);
});

portalRoutes.get('/report-card', zValidator('query', portalStudentQuerySchema), async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  return c.json(await repo.portalReportCard(c.get('authUser'), c.req.valid('query').studentId));
});

portalRoutes.get('/fees', zValidator('query', portalStudentQuerySchema), async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  return c.json(await repo.portalFeeSummary(c.get('authUser'), c.req.valid('query').studentId));
});

portalRoutes.get('/id-card', zValidator('query', portalStudentQuerySchema), async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  return c.json(await repo.portalIdCard(c.get('authUser'), c.req.valid('query').studentId));
});


