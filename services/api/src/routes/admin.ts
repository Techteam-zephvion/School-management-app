import { zValidator } from '@hono/zod-validator';
import { Hono } from 'hono';
import { z } from 'zod';
import { generateJsonWithUsage } from '../ai/client';
import { createDb } from '../db/client';
import { requireRole } from '../http/auth';
import { ApiError } from '../http/errors';
import { createSchoolRepository } from '../repositories/school-repository';
import { DocumentStorage } from '../storage/r2-storage';
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
  createFeeStructureSchema,
  updateFeeStructureSchema,
  createFeeAllocationSchema,
  recordFeePaymentSchema,
  feeAllocationQuerySchema,
  feePaymentQuerySchema,
  createAdmissionApplicationSchema,
  updateAdmissionApplicationSchema,
  enrollApplicantSchema,
  admissionQuerySchema,
  addAdmissionDocumentSchema,
  updateAdmissionDocumentSchema,
  bulkImportPreviewSchema,
  bulkImportCommitSchema,
  onboardingWizardSchema,
  sendNotificationSchema,
  notificationQuerySchema,
  recordConsentSchema,
  createDsrRequestSchema,
  resolveDsrRequestSchema,
  auditLogQuerySchema,
  createFeeConcessionSchema,
  applyStudentConcessionSchema,
  createFeeRefundSchema,
  updateRefundStatusSchema,
  createFeeStructureHeadSchema,
  assignSectionClassTeacherSchema,
  createStudentLeaveSchema,
  updateStudentLeaveStatusSchema,
  createStaffLeaveSchema,
  updateStaffLeaveStatusSchema,
  createTransportVehicleSchema,
  createTransportDriverSchema,
  createTransportRouteSchema,
  createTransportStopSchema,
  createTransportAllocationSchema,
  createTransportLogSchema,
  issueCertificateSchema,
  revokeCertificateSchema,
  createCalendarEventSchema,
  createPtmScheduleSchema,
  updatePtmSlotNotesSchema,
  createGradingSchemeSchema,
  createGradingScaleSchema,
  createEvaluationComponentSchema,
  generateReportCardsSchema,
  publishReportCardSchema,
  evaluateStudentRiskSchema,
  recordStudentInterventionSchema,
  naturalLanguageQuerySchema,
} from '../http/validation';


export const adminRoutes = new Hono<AppBindings>();

adminRoutes.use('*', async (c, next) => {
  const user = c.get('authUser');
  requireRole(user, ['admin', 'principal', 'accountant', 'admissions_officer']);

  const path = c.req.path;
  const method = c.req.method;

  // Principal has read-only institutional oversight (NL query is read-only analytics)
  if (user.roles.includes('principal') && !user.roles.includes('admin')) {
    if (method !== 'GET' && !path.includes('/analytics/natural-language-query')) {
      throw new ApiError(403, 'Principal role has read-only institutional access');
    }
  }

  // Accountant is restricted to finance, fee, concession, and refund endpoints
  if (
    user.roles.includes('accountant') &&
    !user.roles.includes('admin') &&
    !user.roles.includes('principal')
  ) {
    const isFeeOrFinance =
      path.includes('/fees') ||
      path.includes('/concessions') ||
      path.includes('/refunds') ||
      path.includes('/overview');
    if (!isFeeOrFinance) {
      throw new ApiError(403, 'Accountant role is restricted to financial operations');
    }
  }

  // Admissions Officer is restricted to admissions, student records, and onboarding
  if (
    user.roles.includes('admissions_officer') &&
    !user.roles.includes('admin') &&
    !user.roles.includes('principal')
  ) {
    const isAdmissions =
      path.includes('/admissions') ||
      path.includes('/students') ||
      path.includes('/onboarding') ||
      path.includes('/overview') ||
      path.includes('/dpdp') ||
      path.includes('/certificates');
    if (!isAdmissions) {
      throw new ApiError(403, 'Admissions Officer role is restricted to admissions and enrollment');
    }
  }

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

adminRoutes.get('/fees/summary', async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  return c.json(await repo.feeSummary(c.get('authUser')));
});

adminRoutes
  .get('/fees/structures', async (c) => {
    const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
    const yearId = c.req.query('academicYearId');
    return c.json(await repo.listFeeStructures(c.get('authUser'), yearId));
  })
  .post('/fees/structures', zValidator('json', createFeeStructureSchema), async (c) => {
    const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
    return c.json(await repo.createFeeStructure(c.get('authUser'), c.req.valid('json')), 201);
  });

adminRoutes.patch(
  '/fees/structures/:id',
  zValidator('param', idSchema),
  zValidator('json', updateFeeStructureSchema),
  async (c) => {
    const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
    return c.json(await repo.updateFeeStructure(c.get('authUser'), c.req.valid('param').id, c.req.valid('json')));
  },
);

adminRoutes.delete('/fees/structures/:id', zValidator('param', idSchema), async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  return c.json(await repo.deleteFeeStructure(c.get('authUser'), c.req.valid('param').id));
});

adminRoutes
  .get('/fees/allocations', zValidator('query', feeAllocationQuerySchema), async (c) => {
    const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
    return c.json(await repo.listFeeAllocations(c.get('authUser'), c.req.valid('query')));
  })
  .post('/fees/allocations', zValidator('json', createFeeAllocationSchema), async (c) => {
    const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
    return c.json(await repo.createFeeAllocation(c.get('authUser'), c.req.valid('json')), 201);
  });

adminRoutes
  .get('/fees/payments', zValidator('query', feePaymentQuerySchema), async (c) => {
    const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
    return c.json(await repo.listFeePayments(c.get('authUser'), c.req.valid('query')));
  })
  .post('/fees/payments', zValidator('json', recordFeePaymentSchema), async (c) => {
    const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
    return c.json(await repo.recordFeePayment(c.get('authUser'), c.req.valid('json')), 201);
  });

adminRoutes.get('/admissions/summary', async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  const yearId = c.req.query('academicYearId');
  return c.json(await repo.admissionSummary(c.get('authUser'), yearId));
});

adminRoutes
  .get('/admissions/applications', zValidator('query', admissionQuerySchema), async (c) => {
    const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
    return c.json(await repo.listAdmissionApplications(c.get('authUser'), c.req.valid('query')));
  })
  .post('/admissions/applications', zValidator('json', createAdmissionApplicationSchema), async (c) => {
    const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
    return c.json(await repo.createAdmissionApplication(c.get('authUser'), c.req.valid('json')), 201);
  });

adminRoutes
  .get('/admissions/applications/:id', zValidator('param', idSchema), async (c) => {
    const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
    return c.json(await repo.getAdmissionApplication(c.get('authUser'), c.req.valid('param').id));
  })
  .patch(
    '/admissions/applications/:id',
    zValidator('param', idSchema),
    zValidator('json', updateAdmissionApplicationSchema),
    async (c) => {
      const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
      return c.json(await repo.updateAdmissionApplication(c.get('authUser'), c.req.valid('param').id, c.req.valid('json')));
    },
  )
  .delete('/admissions/applications/:id', zValidator('param', idSchema), async (c) => {
    const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
    return c.json(await repo.deleteAdmissionApplication(c.get('authUser'), c.req.valid('param').id));
  });

adminRoutes.post(
  '/admissions/applications/:id/enroll',
  zValidator('param', idSchema),
  zValidator('json', enrollApplicantSchema),
  async (c) => {
    const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
    return c.json(await repo.enrollApplicant(c.get('authUser'), c.req.valid('param').id, c.req.valid('json')), 201);
  },
);

adminRoutes
  .get(
    '/admissions/applications/:id/documents',
    zValidator('param', idSchema),
    async (c) => {
      const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
      return c.json(await repo.listAdmissionDocuments(c.get('authUser'), c.req.valid('param').id));
    },
  )
  .post(
    '/admissions/applications/:id/documents',
    zValidator('param', idSchema),
    zValidator('json', addAdmissionDocumentSchema),
    async (c) => {
      const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
      return c.json(await repo.addAdmissionDocument(c.get('authUser'), c.req.valid('param').id, c.req.valid('json')), 201);
    },
  );

adminRoutes
  .patch(
    '/admissions/documents/:id',
    zValidator('param', idSchema),
    zValidator('json', updateAdmissionDocumentSchema),
    async (c) => {
      const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
      return c.json(await repo.updateAdmissionDocument(c.get('authUser'), c.req.valid('param').id, c.req.valid('json')));
    },
  )
  .delete(
    '/admissions/documents/:id',
    zValidator('param', idSchema),
    async (c) => {
      const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
      const res = await repo.deleteAdmissionDocument(c.get('authUser'), c.req.valid('param').id);
      if (res.deletedFileKey) {
        const storage = new DocumentStorage(c.env.DOCUMENTS_BUCKET);
        await storage.deleteFile(res.deletedFileKey);
      }
      return c.json(res);
    },
  );

adminRoutes
  .post(
    '/admissions/applications/:id/documents/:docId/upload',
    zValidator('param', z.object({ id: z.string().uuid(), docId: z.string().uuid() })),
    async (c) => {
      const { id: applicationId, docId } = c.req.valid('param');
      const authUser = c.get('authUser');
      const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));

      const body = await c.req.parseBody();
      const file = body['file'];

      let fileName = 'document.pdf';
      let contentType = 'application/octet-stream';
      let bytes: Uint8Array;

      if (file && typeof file === 'object' && 'arrayBuffer' in file) {
        const f = file as File;
        fileName = f.name || fileName;
        contentType = f.type || contentType;
        bytes = new Uint8Array(await f.arrayBuffer());
      } else if (typeof file === 'string') {
        bytes = new TextEncoder().encode(file);
      } else {
        const raw = await c.req.arrayBuffer();
        if (raw.byteLength === 0) {
          throw new ApiError(400, 'No file uploaded');
        }
        bytes = new Uint8Array(raw);
        contentType = c.req.header('content-type') || contentType;
        const headerName = c.req.header('x-filename');
        if (headerName) fileName = headerName;
      }

      const storage = new DocumentStorage(c.env.DOCUMENTS_BUCKET);
      const stored = await storage.uploadFile({
        schoolId: authUser.schoolId,
        applicationId,
        documentId: docId,
        fileName,
        contentType,
        data: bytes,
      });

      const updated = await repo.attachAdmissionDocumentFile(authUser, applicationId, docId, stored);
      return c.json(updated, 201);
    },
  )
  .get(
    '/admissions/applications/:id/documents/:docId/download',
    zValidator('param', z.object({ id: z.string().uuid(), docId: z.string().uuid() })),
    async (c) => {
      const { id: applicationId, docId } = c.req.valid('param');
      const authUser = c.get('authUser');
      const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));

      const doc = await repo.getAdmissionDocument(authUser, docId);
      if (!doc.fileKey) {
        throw new ApiError(404, 'No file is attached to this document');
      }

      const storage = new DocumentStorage(c.env.DOCUMENTS_BUCKET);
      const file = await storage.getFile(doc.fileKey);
      if (!file) {
        throw new ApiError(404, 'Attached file was not found in storage');
      }

      c.header('Content-Type', file.contentType);
      c.header('Content-Length', String(file.contentLength));
      c.header('Content-Disposition', `inline; filename="${doc.fileName || file.fileName}"`);
      c.header('Cache-Control', 'private, max-age=3600');

      return c.body(file.body as any);
    },
  )
  .delete(
    '/admissions/documents/:id/file',
    zValidator('param', idSchema),
    async (c) => {
      const { id } = c.req.valid('param');
      const authUser = c.get('authUser');
      const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));

      const res = await repo.removeAdmissionDocumentFile(authUser, id);
      if (res.deletedFileKey) {
        const storage = new DocumentStorage(c.env.DOCUMENTS_BUCKET);
        await storage.deleteFile(res.deletedFileKey);
      }
      return c.json({ success: true, document: res.document });
    },
  );


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

adminRoutes.post('/imports/preview', zValidator('json', bulkImportPreviewSchema), async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  const body = c.req.valid('json');
  return c.json(await repo.previewBulkImport(c.get('authUser'), body.entity, body.csv));
});

adminRoutes.post('/imports/commit', zValidator('json', bulkImportCommitSchema), async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  const body = c.req.valid('json');
  return c.json(await repo.commitBulkImport(c.get('authUser'), body), 201);
});

adminRoutes.get('/onboarding/status', async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  return c.json(await repo.getOnboardingStatus(c.get('authUser')));
});

adminRoutes.post('/onboarding/wizard', zValidator('json', onboardingWizardSchema), async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  const body = c.req.valid('json');
  return c.json(await repo.runOnboardingWizard(c.get('authUser'), body), 201);
});

adminRoutes.get('/notifications', zValidator('query', notificationQuerySchema), async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  return c.json(await repo.listNotifications(c.get('authUser'), c.req.valid('query')));
});

adminRoutes.post('/notifications/send', zValidator('json', sendNotificationSchema), async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  const body = c.req.valid('json');
  return c.json(await repo.sendNotification(c.get('authUser'), body, c.env), 201);
});

adminRoutes.post(
  '/notifications/trigger-absence-alerts',
  zValidator('json', z.object({ sessionId: z.string().uuid() })),
  async (c) => {
    const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
    const body = c.req.valid('json');
    return c.json(await repo.triggerAbsenceAlertsForSession(c.get('authUser'), body.sessionId, c.env));
  },
);

adminRoutes.post(
  '/notifications/trigger-fee-reminders',
  zValidator('query', z.object({ days: z.coerce.number().optional() })),
  async (c) => {
    const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
    const query = c.req.valid('query');
    return c.json(await repo.triggerPendingFeeReminders(c.get('authUser'), query.days ?? 7, c.env));
  },
);

// Phase 11: Audit Logs
adminRoutes.get('/audit-logs', zValidator('query', auditLogQuerySchema), async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  const query = c.req.valid('query');
  return c.json(await repo.listAuditLogs(c.get('authUser'), query));
});

// Phase 11: DPDP Consents
adminRoutes.get(
  '/dpdp/consents',
  zValidator(
    'query',
    z.object({
      studentId: z.string().uuid().optional(),
      status: z.enum(['granted', 'revoked', 'expired']).optional(),
    }),
  ),
  async (c) => {
    const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
    return c.json(await repo.listDpdpConsents(c.get('authUser'), c.req.valid('query')));
  },
);

adminRoutes.post('/dpdp/consents', zValidator('json', recordConsentSchema), async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  return c.json(await repo.recordDpdpConsent(c.get('authUser'), c.req.valid('json')), 201);
});

// Phase 11: Data Subject Rights (DSR) Requests
adminRoutes.get(
  '/dpdp/dsr',
  zValidator(
    'query',
    z.object({
      status: z.enum(['pending', 'in_review', 'fulfilled', 'rejected']).optional(),
    }),
  ),
  async (c) => {
    const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
    return c.json(await repo.listDsrRequests(c.get('authUser'), c.req.valid('query').status));
  },
);

adminRoutes.put(
  '/dpdp/dsr/:id',
  zValidator('param', z.object({ id: z.string().uuid() })),
  zValidator('json', resolveDsrRequestSchema),
  async (c) => {
    const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
    return c.json(
      await repo.resolveDsrRequest(c.get('authUser'), c.req.valid('param').id, c.req.valid('json')),
    );
  },
);

// Phase 11: Class Teacher Designation on Section
adminRoutes.put(
  '/sections/:id/class-teacher',
  zValidator('param', z.object({ id: z.string().uuid() })),
  zValidator('json', assignSectionClassTeacherSchema),
  async (c) => {
    const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
    return c.json(
      await repo.assignSectionClassTeacher(
        c.get('authUser'),
        c.req.valid('param').id,
        c.req.valid('json').classTeacherStaffId,
      ),
    );
  },
);

// Phase 11: Fee Concessions
adminRoutes.get('/fees/concessions', async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  return c.json(await repo.listFeeConcessions(c.get('authUser')));
});

adminRoutes.post('/fees/concessions', zValidator('json', createFeeConcessionSchema), async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  return c.json(await repo.createFeeConcession(c.get('authUser'), c.req.valid('json')), 201);
});

adminRoutes.post(
  '/fees/concessions/apply',
  zValidator('json', applyStudentConcessionSchema),
  async (c) => {
    const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
    return c.json(await repo.applyStudentConcession(c.get('authUser'), c.req.valid('json')), 201);
  },
);

adminRoutes.get(
  '/fees/concessions/applied',
  zValidator(
    'query',
    z.object({
      studentId: z.string().uuid().optional(),
      allocationId: z.string().uuid().optional(),
    }),
  ),
  async (c) => {
    const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
    return c.json(await repo.listStudentConcessions(c.get('authUser'), c.req.valid('query')));
  },
);

// Phase 11: Fee Refunds
adminRoutes.get(
  '/fees/refunds',
  zValidator(
    'query',
    z.object({
      status: z.enum(['pending', 'approved', 'processed', 'rejected']).optional(),
    }),
  ),
  async (c) => {
    const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
    return c.json(await repo.listFeeRefunds(c.get('authUser'), c.req.valid('query').status));
  },
);

adminRoutes.post('/fees/refunds', zValidator('json', createFeeRefundSchema), async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  return c.json(await repo.createFeeRefund(c.get('authUser'), c.req.valid('json')), 201);
});

adminRoutes.put(
  '/fees/refunds/:id/status',
  zValidator('param', z.object({ id: z.string().uuid() })),
  zValidator('json', updateRefundStatusSchema),
  async (c) => {
    const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
    return c.json(
      await repo.updateFeeRefundStatus(
        c.get('authUser'),
        c.req.valid('param').id,
        c.req.valid('json').status,
      ),
    );
  },
);

// Phase 11: Fee Structure Heads
adminRoutes.get(
  '/fees/structures/:id/heads',
  zValidator('param', z.object({ id: z.string().uuid() })),
  async (c) => {
    const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
    return c.json(await repo.listFeeStructureHeads(c.get('authUser'), c.req.valid('param').id));
  },
);

adminRoutes.post(
  '/fees/structures/:id/heads',
  zValidator('param', z.object({ id: z.string().uuid() })),
  zValidator(
    'json',
    z.object({
      headName: z.string().trim().min(2).max(80),
      amount: z.number().int().min(0),
      isOptional: z.boolean().default(false),
    }),
  ),
  async (c) => {
    const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
    return c.json(
      await repo.createFeeStructureHead(c.get('authUser'), {
        ...c.req.valid('json'),
        feeStructureId: c.req.valid('param').id,
      }),
      201,
    );
  },
);

// ==========================================
// Phase 12: School Operations & Daily Differentiators
// ==========================================

// 1. Leaves
adminRoutes.get('/leaves/students', async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  const query = c.req.query();
  return c.json(await repo.listStudentLeaves(c.get('authUser'), {
    studentId: query.studentId,
    status: query.status as any,
  }));
});

adminRoutes.put(
  '/leaves/students/:id/status',
  zValidator('param', z.object({ id: z.string().uuid() })),
  zValidator('json', updateStudentLeaveStatusSchema),
  async (c) => {
    const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
    return c.json(
      await repo.updateStudentLeaveStatus(
        c.get('authUser'),
        c.req.valid('param').id,
        c.req.valid('json'),
      ),
    );
  },
);

adminRoutes.get('/leaves/staff', async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  const query = c.req.query();
  return c.json(await repo.listStaffLeaves(c.get('authUser'), {
    staffId: query.staffId,
    status: query.status as any,
  }));
});

adminRoutes.post('/leaves/staff', zValidator('json', createStaffLeaveSchema), async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  return c.json(await repo.createStaffLeave(c.get('authUser'), c.req.valid('json')), 201);
});

adminRoutes.put(
  '/leaves/staff/:id/status',
  zValidator('param', z.object({ id: z.string().uuid() })),
  zValidator('json', updateStaffLeaveStatusSchema),
  async (c) => {
    const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
    return c.json(
      await repo.updateStaffLeaveStatus(
        c.get('authUser'),
        c.req.valid('param').id,
        c.req.valid('json'),
      ),
    );
  },
);

adminRoutes.get(
  '/leaves/staff/:id/substitutes',
  zValidator('param', z.object({ id: z.string().uuid() })),
  async (c) => {
    const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
    return c.json(await repo.suggestStaffLeaveSubstitutes(c.get('authUser'), c.req.valid('param').id));
  },
);

// 2. Transport
adminRoutes.get('/transport/vehicles', async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  return c.json(await repo.listTransportVehicles(c.get('authUser')));
});

adminRoutes.post('/transport/vehicles', zValidator('json', createTransportVehicleSchema), async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  return c.json(await repo.createTransportVehicle(c.get('authUser'), c.req.valid('json')), 201);
});

adminRoutes.get('/transport/drivers', async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  return c.json(await repo.listTransportDrivers(c.get('authUser')));
});

adminRoutes.post('/transport/drivers', zValidator('json', createTransportDriverSchema), async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  return c.json(await repo.createTransportDriver(c.get('authUser'), c.req.valid('json')), 201);
});

adminRoutes.get('/transport/routes', async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  return c.json(await repo.listTransportRoutes(c.get('authUser')));
});

adminRoutes.post('/transport/routes', zValidator('json', createTransportRouteSchema), async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  return c.json(await repo.createTransportRoute(c.get('authUser'), c.req.valid('json')), 201);
});

adminRoutes.get(
  '/transport/routes/:id/stops',
  zValidator('param', z.object({ id: z.string().uuid() })),
  async (c) => {
    const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
    return c.json(await repo.listTransportStops(c.get('authUser'), c.req.valid('param').id));
  },
);

adminRoutes.post('/transport/stops', zValidator('json', createTransportStopSchema), async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  return c.json(await repo.createTransportStop(c.get('authUser'), c.req.valid('json')), 201);
});

adminRoutes.get('/transport/allocations', async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  const query = c.req.query();
  return c.json(await repo.listStudentTransportAllocations(c.get('authUser'), {
    studentId: query.studentId,
    routeId: query.routeId,
  }));
});

adminRoutes.post('/transport/allocations', zValidator('json', createTransportAllocationSchema), async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  return c.json(await repo.createStudentTransportAllocation(c.get('authUser'), c.req.valid('json')), 201);
});

adminRoutes.get('/transport/logs', async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  const query = c.req.query();
  return c.json(await repo.listTransportLogs(c.get('authUser'), {
    routeId: query.routeId,
    date: query.date,
  }));
});

adminRoutes.post('/transport/logs', zValidator('json', createTransportLogSchema), async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  return c.json(await repo.createTransportLog(c.get('authUser'), c.req.valid('json')), 201);
});

// 3. Certificates
adminRoutes.get('/certificates', async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  const query = c.req.query();
  return c.json(await repo.listCertificates(c.get('authUser'), {
    studentId: query.studentId,
    certificateType: query.certificateType as any,
  }));
});

adminRoutes.post('/certificates/issue', zValidator('json', issueCertificateSchema), async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  return c.json(await repo.issueCertificate(c.get('authUser'), c.req.valid('json')), 201);
});

adminRoutes.get(
  '/certificates/:id',
  zValidator('param', z.object({ id: z.string().uuid() })),
  async (c) => {
    const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
    return c.json(await repo.getCertificateById(c.get('authUser'), c.req.valid('param').id));
  },
);

adminRoutes.put(
  '/certificates/:id/revoke',
  zValidator('param', z.object({ id: z.string().uuid() })),
  zValidator('json', revokeCertificateSchema.optional()),
  async (c) => {
    const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
    const reason = c.req.valid('json')?.reason;
    return c.json(await repo.revokeCertificate(c.get('authUser'), c.req.valid('param').id, reason));
  },
);

// 4. Calendar & PTM
adminRoutes.get('/calendar', async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  const query = c.req.query();
  return c.json(await repo.listCalendarEvents(c.get('authUser'), {
    targetAudience: query.targetAudience,
    startDate: query.startDate,
    endDate: query.endDate,
  }));
});

adminRoutes.post('/calendar', zValidator('json', createCalendarEventSchema), async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  return c.json(await repo.createCalendarEvent(c.get('authUser'), c.req.valid('json')), 201);
});

adminRoutes.delete(
  '/calendar/:id',
  zValidator('param', z.object({ id: z.string().uuid() })),
  async (c) => {
    const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
    return c.json(await repo.deleteCalendarEvent(c.get('authUser'), c.req.valid('param').id));
  },
);

adminRoutes.get('/ptm/schedules', async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  return c.json(await repo.listPtmSchedules(c.get('authUser')));
});

adminRoutes.post('/ptm/schedules', zValidator('json', createPtmScheduleSchema), async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  return c.json(await repo.createPtmSchedule(c.get('authUser'), c.req.valid('json')), 201);
});

adminRoutes.get('/ptm/slots', async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  const query = c.req.query();
  return c.json(await repo.listPtmSlots(c.get('authUser'), {
    scheduleId: query.scheduleId,
    teacherStaffId: query.teacherStaffId,
    studentId: query.studentId,
    status: query.status as any,
  }));
});

// Phase 13: Academic Depth & Board-Specific Grading Schemes

adminRoutes.get('/academics/grading-schemes', async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  const academicYearId = c.req.query('academicYearId');
  return c.json(await repo.listGradingSchemes(c.get('authUser'), academicYearId));
});

adminRoutes.post('/academics/grading-schemes', zValidator('json', createGradingSchemeSchema), async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  return c.json(await repo.createGradingScheme(c.get('authUser'), c.req.valid('json')), 201);
});

adminRoutes.get(
  '/academics/grading-schemes/:id',
  zValidator('param', z.object({ id: z.string().uuid() })),
  async (c) => {
    const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
    return c.json(await repo.getGradingScheme(c.get('authUser'), c.req.valid('param').id));
  },
);

adminRoutes.post('/academics/grading-schemes/seed-defaults', async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  const academicYearId = c.req.query('academicYearId');
  return c.json(await repo.seedDefaultBoardGradingSchemes(c.get('authUser'), academicYearId), 201);
});

adminRoutes.post('/academics/grading-schemes/scales', zValidator('json', createGradingScaleSchema), async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  return c.json(await repo.createGradingScale(c.get('authUser'), c.req.valid('json')), 201);
});

adminRoutes.post('/academics/grading-schemes/components', zValidator('json', createEvaluationComponentSchema), async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  return c.json(await repo.createEvaluationComponent(c.get('authUser'), c.req.valid('json')), 201);
});

adminRoutes.post('/academics/report-cards/generate', zValidator('json', generateReportCardsSchema), async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  return c.json(await repo.generateReportCards(c.get('authUser'), c.req.valid('json')), 201);
});

adminRoutes.get('/academics/report-cards', async (c) => {
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

adminRoutes.get(
  '/academics/report-cards/:id',
  zValidator('param', z.object({ id: z.string().uuid() })),
  async (c) => {
    const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
    return c.json(await repo.getReportCard(c.get('authUser'), c.req.valid('param').id));
  },
);

adminRoutes.put(
  '/academics/report-cards/:id/publish',
  zValidator('param', z.object({ id: z.string().uuid() })),
  zValidator('json', publishReportCardSchema),
  async (c) => {
    const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
    return c.json(await repo.publishReportCard(c.get('authUser'), c.req.valid('param').id, c.req.valid('json').isPublished));
  },
);

adminRoutes.get('/academics/offline-sync-logs', async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  const staffId = c.req.query('staffId');
  return c.json(await repo.listOfflineAttendanceSyncLogs(c.get('authUser'), staffId));
});

// Phase 14: Applied AI & Enhanced Institutional UX
adminRoutes.post(
  '/analytics/at-risk-students/evaluate',
  zValidator('json', evaluateStudentRiskSchema.optional()),
  async (c) => {
    const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
    const input = c.req.valid('json');
    return c.json(await repo.evaluateStudentRiskScores(c.get('authUser'), input), 200);
  },
);

adminRoutes.get('/analytics/at-risk-students', async (c) => {
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

adminRoutes.get(
  '/analytics/at-risk-students/:studentId',
  zValidator('param', z.object({ studentId: z.string().uuid() })),
  async (c) => {
    const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
    return c.json(await repo.getStudentRiskAlert(c.get('authUser'), c.req.valid('param').studentId));
  },
);

adminRoutes.post(
  '/analytics/at-risk-students/:studentId/intervene',
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

adminRoutes.post(
  '/analytics/natural-language-query',
  zValidator('json', naturalLanguageQuerySchema),
  async (c) => {
    const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
    return c.json(await repo.executeNaturalLanguageQuery(c.get('authUser'), c.req.valid('json')), 200);
  },
);



