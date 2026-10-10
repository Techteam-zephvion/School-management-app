import { zValidator } from '@hono/zod-validator';
import { Hono } from 'hono';
import { z } from 'zod';
import { createDb } from '../db/client';
import { requireRole } from '../http/auth';
import { createSchoolRepository } from '../repositories/school-repository';
import type { AppBindings } from '../types';
import {
  createAcademicYearSchema,
  createClassSchema,
  createSectionSchema,
  createStaffSchema,
  createStudentSchema,
  createSubjectSchema,
  createTeacherAssignmentSchema,
  createUserSchema,
} from '../http/validation';

export const adminRoutes = new Hono<AppBindings>();

adminRoutes.use('*', async (c, next) => {
  requireRole(c.get('authUser'), ['admin']);
  await next();
});

const attendanceSummaryQuerySchema = z.object({
  startDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Invalid startDate format (expected YYYY-MM-DD)').optional(),
  endDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Invalid endDate format (expected YYYY-MM-DD)').optional(),
  classId: z.string().uuid().optional(),
  sectionId: z.string().uuid().optional(),
  format: z.enum(['json', 'csv']).optional(),
});

function sanitizeCsvValue(val: unknown): string {
  if (val === null || val === undefined) return '""';
  let str = String(val);
  // CWE-1236: Prevent CSV formula injection if cell begins with =, +, -, @, \t, or \r
  if (/^[=+\-@\t\r]/.test(str)) {
    str = `'${str}`;
  }
  return `"${str.replace(/"/g, '""')}"`;
}

adminRoutes.get('/overview', async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  return c.json(await repo.overview(c.get('authUser')));
});

adminRoutes.post('/users', zValidator('json', createUserSchema), async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  return c.json(await repo.createUser(c.get('authUser'), c.req.valid('json')), 201);
});

adminRoutes
  .get('/academic-years', async (c) => {
    const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
    return c.json(await repo.listAcademicYears(c.get('authUser')));
  })
  .post('/academic-years', zValidator('json', createAcademicYearSchema), async (c) => {
    const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
    return c.json(await repo.createAcademicYear(c.get('authUser'), c.req.valid('json')), 201);
  });

adminRoutes
  .get('/classes', async (c) => {
    const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
    return c.json(await repo.listClasses(c.get('authUser')));
  })
  .post('/classes', zValidator('json', createClassSchema), async (c) => {
    const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
    return c.json(await repo.createClass(c.get('authUser'), c.req.valid('json')), 201);
  });

adminRoutes
  .get('/sections', async (c) => {
    const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
    return c.json(await repo.listSections(c.get('authUser')));
  })
  .post('/sections', zValidator('json', createSectionSchema), async (c) => {
    const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
    return c.json(await repo.createSection(c.get('authUser'), c.req.valid('json')), 201);
  });

adminRoutes
  .get('/subjects', async (c) => {
    const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
    return c.json(await repo.listSubjects(c.get('authUser')));
  })
  .post('/subjects', zValidator('json', createSubjectSchema), async (c) => {
    const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
    return c.json(await repo.createSubject(c.get('authUser'), c.req.valid('json')), 201);
  });

adminRoutes
  .get('/staff', async (c) => {
    const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
    return c.json(await repo.listStaff(c.get('authUser')));
  })
  .post('/staff', zValidator('json', createStaffSchema), async (c) => {
    const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
    return c.json(await repo.createStaff(c.get('authUser'), c.req.valid('json')), 201);
  });

adminRoutes
  .get('/students', async (c) => {
    const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
    return c.json(await repo.listStudents(c.get('authUser')));
  })
  .post('/students', zValidator('json', createStudentSchema), async (c) => {
    const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
    return c.json(await repo.createStudent(c.get('authUser'), c.req.valid('json')), 201);
  });

adminRoutes
  .get('/teacher-assignments', async (c) => {
    const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
    return c.json(await repo.listTeacherAssignments(c.get('authUser')));
  })
  .post('/teacher-assignments', zValidator('json', createTeacherAssignmentSchema), async (c) => {
    const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
    return c.json(await repo.createTeacherAssignment(c.get('authUser'), c.req.valid('json')), 201);
  });

adminRoutes.get('/attendance-summary', zValidator('query', attendanceSummaryQuerySchema), async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  const query = c.req.valid('query');
  const summary = await repo.attendanceSummary(c.get('authUser'), {
    startDate: query.startDate,
    endDate: query.endDate,
    classId: query.classId,
    sectionId: query.sectionId,
  });

  if (query.format === 'csv') {
    const headers = ['attendanceDate', 'className', 'sectionName', 'kind', 'periodNumber', 'staffName'];
    const csvLines = [
      headers.join(','),
      ...summary.sessions.map((s) =>
        [
          s.attendanceDate ?? '',
          sanitizeCsvValue(s.className),
          sanitizeCsvValue(s.sectionName),
          s.kind ?? '',
          s.periodNumber ?? '',
          sanitizeCsvValue(s.staffName),
        ].join(','),
      ),
    ];
    return new Response(csvLines.join('\n'), {
      headers: {
        'content-type': 'text/csv; charset=utf-8',
        'content-disposition': 'attachment; filename="attendance-summary.csv"',
      },
    });
  }

  return c.json(summary);
});

adminRoutes.get(
  '/students/:id/attendance-summary',
  zValidator('param', z.object({ id: z.string().uuid('Invalid student ID format') })),
  async (c) => {
    const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
    const param = c.req.valid('param');
    return c.json(await repo.studentAttendanceSummary(c.get('authUser'), param.id));
  },
);
