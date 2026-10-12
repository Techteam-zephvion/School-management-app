import { Hono } from 'hono';
import { zValidator } from '@hono/zod-validator';
import { z } from 'zod';
import { generateJsonWithUsage } from '../ai/client';
import { createDb } from '../db/client';
import { requireRole } from '../http/auth';
import { ApiError } from '../http/errors';
import { createSchoolRepository } from '../repositories/school-repository';
import {
  createTeacherMaterialSchema,
  idSchema,
  saveAttendanceSchema,
  teacherCopilotSchema,
  teacherMaterialContentSchema,
  timetableQuerySchema,
  updateTeacherMaterialSchema,
} from '../http/validation';
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

teacherRoutes.get('/timetable', zValidator('query', timetableQuerySchema), async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  return c.json(await repo.teacherTimetable(c.get('authUser'), c.req.valid('query')));
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

teacherRoutes.get('/materials', async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  return c.json(await repo.listTeacherMaterials(c.get('authUser')));
});

teacherRoutes.post('/materials', zValidator('json', createTeacherMaterialSchema), async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  return c.json(await repo.createTeacherMaterial(c.get('authUser'), c.req.valid('json')), 201);
});

teacherRoutes.get('/materials/:id', zValidator('param', idSchema), async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  return c.json(await repo.getTeacherMaterial(c.get('authUser'), c.req.valid('param').id));
});

teacherRoutes.patch('/materials/:id', zValidator('param', idSchema), zValidator('json', updateTeacherMaterialSchema), async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  return c.json(await repo.updateTeacherMaterial(c.get('authUser'), c.req.valid('param').id, c.req.valid('json')));
});

teacherRoutes.delete('/materials/:id', zValidator('param', idSchema), async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  return c.json(await repo.deleteTeacherMaterial(c.get('authUser'), c.req.valid('param').id));
});

const copilotResponseSchema = teacherMaterialContentSchema.extend({
  title: z.string().max(140),
});

teacherRoutes.post('/ai/copilot', zValidator('json', teacherCopilotSchema), async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  const input = c.req.valid('json');
  const authUser = c.get('authUser');
  await enforceAiLimit(repo, authUser, c.env, input.outputType);
  const assignments = await repo.teacherAssignmentsFor(c.get('authUser'));

  const selectedAssignment = assignments.find((assignment) => {
    if (input.classId && assignment.classId !== input.classId) return false;
    if (input.sectionId && assignment.sectionId !== input.sectionId) return false;
    if (input.subjectId && assignment.subjectId !== input.subjectId) return false;
    return true;
  });

  if ((input.classId || input.sectionId || input.subjectId) && !selectedAssignment) {
    return c.json({ error: 'Selected class, section, or subject is not assigned to this teacher.' }, 403);
  }

  const contextAssignment = selectedAssignment ?? assignments[0] ?? null;

  const startedAt = Date.now();
  let modelResult;
  let usage;
  try {
    const generated = await generateJsonWithUsage(c.env, {
      maxTokens: 1200,
      messages: [
        {
          role: 'system',
          content:
            'You are Teacher Copilot for Schoolic. Generate practical teaching material only from the teacher request and authorized class context. Do not include student names or private records. Return strict JSON.',
        },
        {
          role: 'user',
          content: JSON.stringify({
            task: 'Create teacher-ready instructional material.',
            outputShape: {
              title: 'string',
              overview: 'string',
              sections: [{ heading: 'string', items: ['string'] }],
              checksForUnderstanding: ['string'],
              teacherNotes: ['string'],
            },
            request: input,
            authorizedContext: contextAssignment
              ? {
                  className: contextAssignment.className,
                  sectionName: contextAssignment.sectionName,
                  subjectName: contextAssignment.subjectName,
                }
              : null,
            constraints: [
              'Keep content age-appropriate for the class context when available.',
              'Make the output immediately usable by a teacher.',
              'For quizzes, include answer keys inside teacherNotes.',
              'For worksheets, include clear student instructions and exercise items.',
              'For lesson plans, include timing, activities, and assessment prompts.',
              `Write in ${input.language}.`,
              `For quizzes, produce about ${input.questionCount} questions.`,
            ],
          }),
        },
      ],
      schema: copilotResponseSchema,
    });
    modelResult = generated.data;
    usage = generated.usage;
    await repo.recordAiUsage(authUser, {
      feature: 'teacher_copilot',
      generationType: input.outputType,
      status: 'success',
      ...usage,
    });
  } catch (error) {
    await repo.recordAiUsage(authUser, {
      feature: 'teacher_copilot',
      generationType: input.outputType,
      status: 'failure',
      latencyMs: Date.now() - startedAt,
      model: c.env.AI_MODEL ?? null,
      errorCategory: errorCategory(error),
    });
    throw error;
  }

  return c.json({
    ...modelResult,
    context: contextAssignment
      ? {
          className: contextAssignment.className,
          sectionName: contextAssignment.sectionName,
          subjectName: contextAssignment.subjectName,
        }
      : null,
    metadata: {
      promptVersion: 'teacher-copilot-v1',
      generatedAt: new Date().toISOString(),
      model: c.env.AI_MODEL ?? null,
    },
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
      feature: 'teacher_copilot',
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
