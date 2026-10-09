import { Hono } from 'hono';
import { zValidator } from '@hono/zod-validator';
import { z } from 'zod';
import { createDb } from '../db/client';
import { requireRole } from '../http/auth';
import { createSchoolRepository } from '../repositories/school-repository';
import { saveAttendanceSchema } from '../http/validation';
import type { AppBindings } from '../types';

export const teacherRoutes = new Hono<AppBindings>();

teacherRoutes.use('*', async (c, next) => {
  requireRole(c.get('authUser'), ['admin', 'teacher']);
  await next();
});

teacherRoutes.get('/assignments', async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  return c.json(await repo.teacherAssignmentsFor(c.get('authUser')));
});

teacherRoutes.get(
  '/roster',
  zValidator(
    'query',
    z.object({
      sectionId: z.uuid(),
      academicYearId: z.uuid(),
    }),
  ),
  async (c) => {
    const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
    const query = c.req.valid('query');
    return c.json(await repo.rosterForSection(c.get('authUser'), query.sectionId, query.academicYearId));
  },
);

teacherRoutes.post('/attendance', zValidator('json', saveAttendanceSchema), async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  return c.json(await repo.saveAttendance(c.get('authUser'), c.req.valid('json')), 201);
});

teacherRoutes.get('/attendance/summary', async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  return c.json(await repo.attendanceSummary(c.get('authUser')));
});
