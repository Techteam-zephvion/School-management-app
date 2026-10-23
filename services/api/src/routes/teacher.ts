import { Hono } from 'hono';
import { zValidator } from '@hono/zod-validator';
import { z } from 'zod';
import { generateJsonWithUsage } from '../ai/client';
import { createDb } from '../db/client';
import { requireRole } from '../http/auth';
import { ApiError } from '../http/errors';
import { createSchoolRepository } from '../repositories/school-repository';
import {
  createAnnouncementSchema,
  createHomeworkAssignmentSchema,
  createTeacherMaterialSchema,
  idSchema,
  saveAttendanceSchema,
  saveExamMarksSchema,
  teacherCopilotSchema,
  teacherMaterialContentSchema,
  timetableQuerySchema,
  updateTeacherMaterialSchema,
  updateHomeworkAssignmentSchema,
  gradeHomeworkSubmissionSchema,
  sendChatMessageSchema,
  updateTeacherAvailabilitySchema,
  createStaffLeaveSchema,
  updateStudentLeaveStatusSchema,
  updatePtmSlotNotesSchema,
  syncOfflineAttendanceSchema,
  generateReportCardsSchema,
  publishReportCardSchema,
  recordStudentInterventionSchema,
  draftReportCardRemarksSchema,
  draftHomeworkFeedbackSchema,
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

teacherRoutes.get('/exams', async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  return c.json(await repo.listTeacherExams(c.get('authUser')));
});

teacherRoutes.get('/exams/:id/roster', zValidator('param', idSchema), async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  return c.json(await repo.examRosterForTeacher(c.get('authUser'), c.req.valid('param').id));
});

teacherRoutes.post('/exam-marks', zValidator('json', saveExamMarksSchema), async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  return c.json(await repo.saveTeacherExamMarks(c.get('authUser'), c.req.valid('json')), 201);
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

teacherRoutes
  .get('/announcements', async (c) => {
    const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
    return c.json(await repo.listTeacherAnnouncements(c.get('authUser')));
  })
  .post('/announcements', zValidator('json', createAnnouncementSchema), async (c) => {
    const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
    return c.json(await repo.createTeacherAnnouncement(c.get('authUser'), c.req.valid('json')), 201);
  });

teacherRoutes
  .get('/homework', async (c) => {
    const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
    return c.json(await repo.listTeacherHomework(c.get('authUser')));
  })
  .post('/homework', zValidator('json', createHomeworkAssignmentSchema), async (c) => {
    const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
    return c.json(await repo.createTeacherHomework(c.get('authUser'), c.req.valid('json')), 201);
  });

teacherRoutes.patch('/homework/:id', zValidator('param', idSchema), zValidator('json', updateHomeworkAssignmentSchema), async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  return c.json(await repo.updateTeacherHomework(c.get('authUser'), c.req.valid('param').id, c.req.valid('json')));
});

teacherRoutes.delete('/homework/:id', zValidator('param', idSchema), async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  return c.json(await repo.deleteTeacherHomework(c.get('authUser'), c.req.valid('param').id));
});

teacherRoutes.get('/homework/:id/submissions', zValidator('param', idSchema), async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  return c.json(await repo.listTeacherHomeworkSubmissions(c.get('authUser'), c.req.valid('param').id));
});

teacherRoutes.post('/homework/submissions/:submissionId/grade', zValidator('json', gradeHomeworkSubmissionSchema), async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  const submissionId = c.req.param('submissionId');
  return c.json(await repo.gradeHomeworkSubmission(c.get('authUser'), submissionId, c.req.valid('json')));
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

teacherRoutes.get('/availability', async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  return c.json(await repo.getTeacherAvailability(c.get('authUser')));
});

teacherRoutes.put('/availability', zValidator('json', updateTeacherAvailabilitySchema), async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  return c.json(await repo.updateTeacherAvailability(c.get('authUser'), c.req.valid('json')));
});

teacherRoutes.get('/chat/conversations', async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  return c.json(await repo.listChatConversations(c.get('authUser')));
});

teacherRoutes.get(
  '/chat/conversations/:id/messages',
  zValidator('param', z.object({ id: z.string().uuid() })),
  async (c) => {
    const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
    return c.json(await repo.listChatMessages(c.get('authUser'), c.req.valid('param').id));
  },
);

teacherRoutes.post(
  '/chat/conversations/:id/messages',
  zValidator('param', z.object({ id: z.string().uuid() })),
  zValidator('json', sendChatMessageSchema),
  async (c) => {
    const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
    return c.json(
      await repo.sendChatMessage(c.get('authUser'), c.req.valid('param').id, c.req.valid('json')),
      201,
    );
  },
);

// ==========================================
// Phase 12: Teacher Operations & Daily Differentiators
// ==========================================

// Leaves
teacherRoutes.get('/my-leaves', async (c) => {
  const authUser = c.get('authUser');
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  return c.json(await repo.listStaffLeaves(authUser, { staffId: authUser.staffId ?? undefined }));
});

teacherRoutes.post('/my-leaves', zValidator('json', createStaffLeaveSchema), async (c) => {
  const authUser = c.get('authUser');
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  return c.json(await repo.createStaffLeave(authUser, c.req.valid('json')), 201);
});

teacherRoutes.get('/student-leaves', async (c) => {
  const authUser = c.get('authUser');
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  return c.json(await repo.listStudentLeaves(authUser));
});

teacherRoutes.put(
  '/student-leaves/:id/status',
  zValidator('param', z.object({ id: z.string().uuid() })),
  zValidator('json', updateStudentLeaveStatusSchema),
  async (c) => {
    const authUser = c.get('authUser');
    const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
    return c.json(
      await repo.updateStudentLeaveStatus(
        authUser,
        c.req.valid('param').id,
        c.req.valid('json'),
      ),
    );
  },
);

teacherRoutes.patch(
  '/student-leaves/:id',
  zValidator('param', z.object({ id: z.string().uuid() })),
  zValidator('json', updateStudentLeaveStatusSchema),
  async (c) => {
    const authUser = c.get('authUser');
    const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
    return c.json(
      await repo.updateStudentLeaveStatus(
        authUser,
        c.req.valid('param').id,
        c.req.valid('json'),
      ),
    );
  },
);

// Calendar & PTM
teacherRoutes.get('/calendar', async (c) => {
  const authUser = c.get('authUser');
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  return c.json(await repo.listCalendarEvents(authUser, { targetAudience: 'teachers' }));
});

teacherRoutes.get('/ptm/slots', async (c) => {
  const authUser = c.get('authUser');
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  return c.json(await repo.listPtmSlots(authUser, { teacherStaffId: authUser.staffId ?? undefined }));
});

teacherRoutes.put(
  '/ptm/slots/:id/notes',
  zValidator('param', z.object({ id: z.string().uuid() })),
  zValidator('json', updatePtmSlotNotesSchema),
  async (c) => {
    const authUser = c.get('authUser');
    const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
    return c.json(
      await repo.updatePtmSlotNotes(
        authUser,
        c.req.valid('param').id,
        c.req.valid('json'),
      ),
    );
  },
);

// Phase 13: Offline-First Attendance Synchronization
teacherRoutes.post('/attendance/sync', zValidator('json', syncOfflineAttendanceSchema), async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  return c.json(await repo.syncOfflineAttendance(c.get('authUser'), c.req.valid('json')));
});

// Phase 13: Teacher Report Cards
teacherRoutes.get('/report-cards', async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  const query = c.req.query();
  return c.json(await repo.listReportCards(c.get('authUser'), {
    classId: query.classId,
    sectionId: query.sectionId,
    academicYearId: query.academicYearId,
    studentId: query.studentId,
    term: query.term,
  }));
});

teacherRoutes.get('/grading-schemes', async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  return c.json(
    await repo.listGradingSchemes(c.get('authUser'), c.req.query('academicYearId')),
  );
});

teacherRoutes.post('/report-cards/generate', zValidator('json', generateReportCardsSchema), async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  return c.json(await repo.generateReportCards(c.get('authUser'), c.req.valid('json')), 201);
});

teacherRoutes.put(
  '/report-cards/:id/publish',
  zValidator('param', idSchema),
  zValidator('json', publishReportCardSchema),
  async (c) => {
    const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
    return c.json(
      await repo.publishTeacherReportCard(
        c.get('authUser'),
        c.req.valid('param').id,
        c.req.valid('json').isPublished,
      ),
    );
  },
);

// Phase 14: Applied AI & Enhanced Institutional UX
teacherRoutes.get('/at-risk-students', async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  const query = c.req.query();
  return c.json(
    await repo.listStudentRiskAlerts(c.get('authUser'), {
      classId: query.classId,
      sectionId: query.sectionId,
      riskLevel: query.riskLevel,
      status: query.status,
    }),
  );
});

teacherRoutes.post(
  '/at-risk-students/:studentId/intervene',
  zValidator('param', z.object({ studentId: z.string().uuid() })),
  zValidator('json', recordStudentInterventionSchema),
  async (c) => {
    const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
    return c.json(
      await repo.recordStudentIntervention(
        c.get('authUser'),
        c.req.valid('param').studentId,
        c.req.valid('json'),
      ),
      200,
    );
  },
);

teacherRoutes.post(
  '/ai/draft-remarks',
  zValidator('json', draftReportCardRemarksSchema),
  async (c) => {
    const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
    return c.json(await repo.draftReportCardRemarks(c.req.valid('json')), 200);
  },
);

teacherRoutes.post(
  '/ai/homework-feedback',
  zValidator('json', draftHomeworkFeedbackSchema),
  async (c) => {
    const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
    return c.json(await repo.draftHomeworkFeedback(c.req.valid('json')), 200);
  },
);
