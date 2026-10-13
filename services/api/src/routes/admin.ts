import { zValidator } from '@hono/zod-validator';
import { Hono } from 'hono';
import { z } from 'zod';
import { generateJsonWithUsage } from '../ai/client';
import { createDb } from '../db/client';
import { requireRole } from '../http/auth';
import { ApiError } from '../http/errors';
import { createSchoolRepository } from '../repositories/school-repository';
import type { AppBindings } from '../types';
import {
  aiAttendanceInsightsSchema,
  createAcademicYearSchema,
  createAnnouncementSchema,
  createExamSchema,
  createClassSchema,
  createSectionSchema,
  createStaffSchema,
  createStudentSchema,
  createStudentGuardianLinkSchema,
  createSubjectSchema,
  createTeacherAssignmentSchema,
  createTimetableEntrySchema,
  createUserSchema,
  idSchema,
  timetableQuerySchema,
  updateTimetableEntrySchema,
  updateExamSchema,
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

const aiUsageQuerySchema = z.object({
  startDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Invalid startDate format (expected YYYY-MM-DD)').optional(),
  endDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Invalid endDate format (expected YYYY-MM-DD)').optional(),
});

const aiFindingSchema = z.object({
  title: z.string().max(120),
  observation: z.string().max(500),
  supportingFigures: z.array(z.string().max(160)).max(4),
  followUp: z.string().max(240),
  evidenceLabel: z.string().max(120).optional(),
});

const aiAttendanceInsightResponseSchema = z.object({
  overview: z.string().max(700),
  observedChanges: z.array(aiFindingSchema).max(5),
  recommendedFollowUp: z.array(z.string().max(180)).max(5),
  limitations: z.array(z.string().max(180)).max(5),
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

adminRoutes.post('/students/guardian-links', zValidator('json', createStudentGuardianLinkSchema), async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  return c.json(await repo.createStudentGuardianLink(c.get('authUser'), c.req.valid('json')), 201);
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

adminRoutes
  .get('/timetable', zValidator('query', timetableQuerySchema), async (c) => {
    const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
    return c.json(await repo.listTimetableEntries(c.get('authUser'), c.req.valid('query')));
  })
  .post('/timetable', zValidator('json', createTimetableEntrySchema), async (c) => {
    const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
    return c.json(await repo.createTimetableEntry(c.get('authUser'), c.req.valid('json')), 201);
  });

adminRoutes
  .put(
    '/timetable/:id',
    zValidator('param', idSchema),
    zValidator('json', updateTimetableEntrySchema),
    async (c) => {
      const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
      return c.json(await repo.updateTimetableEntry(c.get('authUser'), c.req.valid('param').id, c.req.valid('json')));
    },
  )
  .delete('/timetable/:id', zValidator('param', idSchema), async (c) => {
    const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
    return c.json(await repo.deleteTimetableEntry(c.get('authUser'), c.req.valid('param').id));
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

adminRoutes.get('/ai/usage', zValidator('query', aiUsageQuerySchema), async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  return c.json(await repo.aiUsageSummary(c.get('authUser'), c.req.valid('query')));
});

adminRoutes
  .get('/announcements', async (c) => {
    const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
    return c.json(await repo.listAdminAnnouncements(c.get('authUser')));
  })
  .post('/announcements', zValidator('json', createAnnouncementSchema), async (c) => {
    const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
    return c.json(await repo.createAdminAnnouncement(c.get('authUser'), c.req.valid('json')), 201);
  });

adminRoutes
  .get('/exams', async (c) => {
    const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
    return c.json(await repo.listAdminExams(c.get('authUser')));
  })
  .post('/exams', zValidator('json', createExamSchema), async (c) => {
    const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
    return c.json(await repo.createAdminExam(c.get('authUser'), c.req.valid('json')), 201);
  });

adminRoutes.patch('/exams/:id', zValidator('param', idSchema), zValidator('json', updateExamSchema), async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  return c.json(await repo.updateAdminExam(c.get('authUser'), c.req.valid('param').id, c.req.valid('json')));
});

adminRoutes.delete('/exams/:id', zValidator('param', idSchema), async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  return c.json(await repo.deleteAdminExam(c.get('authUser'), c.req.valid('param').id));
});

adminRoutes.post('/ai/attendance-insights', zValidator('json', aiAttendanceInsightsSchema), async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  const input = c.req.valid('json');
  const authUser = c.get('authUser');
  await enforceAiLimit(repo, authUser, c.env, 'attendance_insights');
  const dataset = await repo.attendanceInsightDataset(c.get('authUser'), input);

  const startedAt = Date.now();
  let modelResult;
  try {
    const generated = await generateJsonWithUsage(c.env, {
      maxTokens: 1000,
      messages: [
        {
          role: 'system',
          content:
            'You are Schoolic Insights, an attendance operations analyst. Use only the supplied JSON facts. Do not invent counts, dates, names, causes, diagnoses, or predictions. Return strict JSON matching the requested shape.',
        },
        {
          role: 'user',
          content: JSON.stringify({
            task: 'Explain verified attendance and operations metrics for a school administrator.',
            outputShape: {
              overview: 'string',
              observedChanges: [
                {
                  title: 'string',
                  observation: 'string',
                  supportingFigures: ['string'],
                  followUp: 'string',
                  evidenceLabel: 'string',
                },
              ],
              recommendedFollowUp: ['string'],
              limitations: ['string'],
            },
            rules: [
              'Every quantitative statement must match the supplied metrics.',
              'Say insufficient data when there are too few sessions or records.',
              'Separate observed facts from possible explanations.',
              'Do not mention individual students.',
            ],
            facts: dataset,
          }),
        },
      ],
      schema: aiAttendanceInsightResponseSchema,
    });
    modelResult = generated.data;
    await repo.recordAiUsage(authUser, {
      feature: 'schoolic_insights',
      generationType: 'attendance_insights',
      status: 'success',
      ...generated.usage,
    });
  } catch (error) {
    await repo.recordAiUsage(authUser, {
      feature: 'schoolic_insights',
      generationType: 'attendance_insights',
      status: 'failure',
      latencyMs: Date.now() - startedAt,
      model: c.env.AI_MODEL ?? null,
      errorCategory: errorCategory(error),
    });
    throw error;
  }

  return c.json({
    ...modelResult,
    metrics: dataset.metrics,
    previousMetrics: dataset.previousMetrics,
    sectionMetrics: dataset.sectionMetrics,
    range: dataset.range,
    previousRange: dataset.previousRange,
    reportPath: `/api/v1/admin/attendance-summary?${new URLSearchParams({
      startDate: input.startDate,
      endDate: input.endDate,
      ...(input.classId ? { classId: input.classId } : {}),
      ...(input.sectionId ? { sectionId: input.sectionId } : {}),
    }).toString()}`,
  });
});

async function enforceAiLimit(
  repo: ReturnType<typeof createSchoolRepository>,
  user: AppBindings['Variables']['authUser'],
  env: AppBindings['Bindings'],
  generationType: string,
) {
  const limit = numberFromEnv(env.AI_REQUESTS_PER_USER, 20);
  const windowMinutes = numberFromEnv(env.AI_REQUEST_WINDOW_MINUTES, 60);
  const since = new Date(Date.now() - windowMinutes * 60 * 1000);
  const used = await repo.countAiUsageSince(user, since);
  if (used >= limit) {
    await repo.recordAiUsage(user, {
      feature: 'schoolic_insights',
      generationType,
      status: 'limited',
      errorCategory: 'quota_exceeded',
    });
    throw new ApiError(429, 'AI generation limit reached. Please try again later.');
  }
}

function numberFromEnv(value: string | undefined, fallback: number) {
  const parsed = Number(value);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}

function errorCategory(error: unknown) {
  if (error instanceof Error && error.message.toLowerCase().includes('limit')) return 'quota_exceeded';
  if (error instanceof Error && error.message.toLowerCase().includes('timeout')) return 'timeout';
  if (error instanceof Error && error.message.toLowerCase().includes('rate')) return 'rate_limited';
  return 'provider_error';
}

adminRoutes.get(
  '/students/:id/attendance-summary',
  zValidator('param', z.object({ id: z.string().uuid('Invalid student ID format') })),
  async (c) => {
    const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
    const param = c.req.valid('param');
    return c.json(await repo.studentAttendanceSummary(c.get('authUser'), param.id));
  },
);
