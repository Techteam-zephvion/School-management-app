import { z } from 'zod';

export const idSchema = z.object({
  id: z.uuid(),
});

export const createSchoolSchema = z.object({
  name: z.string().min(2),
  code: z.string().min(2).max(24),
});

export const createAcademicYearSchema = z.object({
  name: z.string().min(4),
  startsOn: z.iso.date(),
  endsOn: z.iso.date(),
  isActive: z.boolean().default(false),
});

export const createClassSchema = z.object({
  name: z.string().min(1),
  sortOrder: z.number().int().default(0),
});

export const createSectionSchema = z.object({
  classId: z.uuid(),
  name: z.string().min(1),
});

export const createSubjectSchema = z.object({
  name: z.string().min(1),
  code: z.string().min(1).max(24),
});

export const createStudentSchema = z.object({
  admissionNumber: z.string().min(1).max(64),
  fullName: z.string().min(2),
  userId: z.uuid().optional(),
  guardianName: z.string().optional(),
  guardianPhone: z.string().optional(),
  academicYearId: z.uuid(),
  classId: z.uuid(),
  sectionId: z.uuid(),
  rollNumber: z.string().optional(),
});

export const createStudentGuardianLinkSchema = z.object({
  studentId: z.uuid(),
  appUserId: z.uuid(),
  relationship: z.string().trim().min(2).max(80).default('guardian'),
});

export const createStaffSchema = z.object({
  staffCode: z.string().min(1).max(64),
  fullName: z.string().min(2),
  email: z.email(),
  phone: z.string().optional(),
  isTeacher: z.boolean().default(true),
  userId: z.uuid().optional(),
});

export const createUserSchema = z.object({
  neonUserId: z.string().min(1),
  email: z.email(),
  displayName: z.string().min(2),
  roles: z.array(z.enum(['admin', 'teacher', 'student', 'parent'])).min(1),
});

export const createTeacherAssignmentSchema = z.object({
  staffId: z.uuid(),
  academicYearId: z.uuid(),
  classId: z.uuid(),
  sectionId: z.uuid(),
  subjectId: z.uuid().nullable().optional(),
  canTakeDailyAttendance: z.boolean().default(false),
});

const clockTimeSchema = z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/, 'Expected HH:MM time');

export const timetableQuerySchema = z.object({
  academicYearId: z.uuid().optional(),
  classId: z.uuid().optional(),
  sectionId: z.uuid().optional(),
  staffId: z.uuid().optional(),
  subjectId: z.uuid().optional(),
  dayOfWeek: z.coerce.number().int().min(1).max(7).optional(),
});

export const portalStudentQuerySchema = z.object({
  studentId: z.uuid().optional(),
});

const timetableEntryBaseSchema = z.object({
  academicYearId: z.uuid(),
  classId: z.uuid(),
  sectionId: z.uuid(),
  subjectId: z.uuid(),
  staffId: z.uuid(),
  dayOfWeek: z.number().int().min(1).max(7),
  startTime: clockTimeSchema,
  endTime: clockTimeSchema,
  periodNumber: z.number().int().positive().nullable().optional(),
  label: z.string().max(80).nullable().optional(),
});

export const createTimetableEntrySchema = timetableEntryBaseSchema.superRefine((value, ctx) => {
  if (value.endTime <= value.startTime) {
    ctx.addIssue({
      code: 'custom',
      message: 'End time must be later than start time',
      path: ['endTime'],
    });
  }
});

export const updateTimetableEntrySchema = timetableEntryBaseSchema.partial().superRefine((value, ctx) => {
  if (value.startTime && value.endTime && value.endTime <= value.startTime) {
    ctx.addIssue({
      code: 'custom',
      message: 'End time must be later than start time',
      path: ['endTime'],
    });
  }
});

export const attendanceRecordInputSchema = z.object({
  studentId: z.uuid(),
  status: z.enum(['present', 'absent', 'late', 'excused']),
  remarks: z.string().optional(),
});

export const saveAttendanceSchema = z
  .object({
    academicYearId: z.uuid(),
    classId: z.uuid(),
    sectionId: z.uuid(),
    subjectId: z.uuid().nullable().optional(),
    kind: z.enum(['daily', 'period']),
    attendanceDate: z.iso.date(),
    periodNumber: z.number().int().positive().nullable().optional(),
    notes: z.string().optional(),
    records: z.array(attendanceRecordInputSchema).min(1),
  })
  .superRefine((value, ctx) => {
    if (value.kind === 'period' && (!value.subjectId || !value.periodNumber)) {
      ctx.addIssue({
        code: 'custom',
        message: 'Period attendance requires subjectId and periodNumber',
        path: ['periodNumber'],
      });
    }
    if (value.kind === 'daily' && value.periodNumber) {
      ctx.addIssue({
        code: 'custom',
        message: 'Daily attendance cannot include a period number',
        path: ['periodNumber'],
      });
    }
  });

export const aiAttendanceInsightsSchema = z
  .object({
    startDate: z.iso.date(),
    endDate: z.iso.date(),
    classId: z.uuid().optional(),
    sectionId: z.uuid().optional(),
  })
  .superRefine((value, ctx) => {
    if (value.endDate < value.startDate) {
      ctx.addIssue({
        code: 'custom',
        message: 'endDate must be on or after startDate',
        path: ['endDate'],
      });
    }
  });

export const teacherCopilotSchema = z.object({
  outputType: z.enum(['lesson_plan', 'worksheet', 'quiz']),
  topic: z.string().trim().min(3).max(160),
  subjectId: z.uuid().optional(),
  classId: z.uuid().optional(),
  sectionId: z.uuid().optional(),
  durationMinutes: z.number().int().min(10).max(120).default(40),
  questionCount: z.number().int().min(3).max(30).default(10),
  difficulty: z.enum(['introductory', 'standard', 'advanced']).default('standard'),
  instructions: z.string().trim().max(500).optional(),
  language: z.string().trim().min(2).max(40).default('English'),
});

export const teacherMaterialContentSchema = z.object({
  overview: z.string().trim().min(1).max(2000),
  sections: z
    .array(
      z.object({
        heading: z.string().trim().min(1).max(120),
        items: z.array(z.string().trim().min(1).max(600)).min(1).max(20),
      }),
    )
    .min(1)
    .max(12),
  checksForUnderstanding: z.array(z.string().trim().min(1).max(300)).max(12).default([]),
  teacherNotes: z.array(z.string().trim().min(1).max(500)).max(12).default([]),
});

export const createTeacherMaterialSchema = z.object({
  type: z.enum(['lesson_plan', 'worksheet', 'quiz']),
  title: z.string().trim().min(1).max(160),
  topic: z.string().trim().min(3).max(160),
  academicYearId: z.uuid().optional(),
  classId: z.uuid().optional(),
  sectionId: z.uuid().optional(),
  subjectId: z.uuid().optional(),
  difficulty: z.enum(['introductory', 'standard', 'advanced']).default('standard'),
  language: z.string().trim().min(2).max(40).default('English'),
  durationMinutes: z.number().int().min(10).max(120).optional(),
  questionCount: z.number().int().min(3).max(30).optional(),
  content: teacherMaterialContentSchema,
  metadata: z.record(z.string(), z.unknown()).optional(),
});

export const updateTeacherMaterialSchema = createTeacherMaterialSchema.partial().extend({
  content: teacherMaterialContentSchema.optional(),
});

export const createAnnouncementSchema = z
  .object({
    audience: z.enum(['school', 'class_section']),
    priority: z.enum(['normal', 'important', 'urgent']).default('normal'),
    classId: z.uuid().optional(),
    sectionId: z.uuid().optional(),
    title: z.string().trim().min(3).max(140),
    body: z.string().trim().min(3).max(2000),
    expiresAt: z.iso.datetime().optional(),
  })
  .superRefine((value, ctx) => {
    if (value.audience === 'class_section' && (!value.classId || !value.sectionId)) {
      ctx.addIssue({
        code: 'custom',
        message: 'Class and section are required for class-section announcements',
        path: ['sectionId'],
      });
    }
    if (value.audience === 'school' && (value.classId || value.sectionId)) {
      ctx.addIssue({
        code: 'custom',
        message: 'School-wide announcements cannot include a class or section target',
        path: ['audience'],
      });
    }
  });

export const createHomeworkAssignmentSchema = z.object({
  academicYearId: z.uuid(),
  classId: z.uuid(),
  sectionId: z.uuid(),
  subjectId: z.uuid().nullable().optional(),
  title: z.string().trim().min(3).max(160),
  instructions: z.string().trim().min(3).max(3000),
  dueDate: z.iso.date(),
  estimatedMinutes: z.number().int().min(5).max(240).nullable().optional(),
  status: z.enum(['draft', 'published', 'archived']).default('published'),
  sourceMaterialId: z.uuid().nullable().optional(),
});

export const updateHomeworkAssignmentSchema = createHomeworkAssignmentSchema.partial();

export const submitHomeworkSchema = z.object({
  studentId: z.uuid().optional(),
  content: z.string().trim().min(1).max(5000),
  attachmentUrl: z.string().trim().max(1000).nullable().optional(),
});

export const gradeHomeworkSubmissionSchema = z.object({
  marksObtained: z.number().int().min(0).max(100).nullable().optional(),
  teacherFeedback: z.string().trim().max(2000).nullable().optional(),
  status: z.enum(['submitted', 'reviewed', 'resubmitted']).default('reviewed'),
});

export const createExamSchema = z.object({
  academicYearId: z.uuid(),
  classId: z.uuid(),
  sectionId: z.uuid(),
  subjectId: z.uuid().nullable().optional(),
  name: z.string().trim().min(2).max(160),
  examDate: z.iso.date(),
  maxMarks: z.number().int().min(1).max(1000),
  status: z.enum(['draft', 'published', 'archived']).default('draft'),
});

export const updateExamSchema = createExamSchema.partial();

export const saveExamMarksSchema = z.object({
  examId: z.uuid(),
  records: z.array(
    z.object({
      studentId: z.uuid(),
      marksObtained: z.number().int().min(0).max(1000),
      remarks: z.string().trim().max(500).optional(),
    }),
  ).min(1).max(200),
});

export const createFeeStructureSchema = z.object({
  academicYearId: z.uuid(),
  name: z.string().trim().min(2).max(100),
  code: z.string().trim().min(2).max(32),
  description: z.string().trim().max(300).nullable().optional(),
  amount: z.number().int().positive().max(10000000),
  frequency: z.enum(['one_time', 'term', 'monthly', 'annual']).default('term'),
  dueDate: z.iso.date().nullable().optional(),
});

export const updateFeeStructureSchema = createFeeStructureSchema.partial();

export const createFeeAllocationSchema = z.object({
  studentId: z.uuid(),
  feeStructureId: z.uuid(),
  academicYearId: z.uuid(),
  amount: z.number().int().positive().max(10000000).optional(),
  dueDate: z.iso.date(),
});

export const recordFeePaymentSchema = z.object({
  allocationId: z.uuid(),
  amountPaid: z.number().int().positive().max(10000000),
  paymentMethod: z.enum(['cash', 'upi', 'card', 'bank_transfer', 'cheque']).default('cash'),
  transactionReference: z.string().trim().max(100).nullable().optional(),
  notes: z.string().trim().max(300).nullable().optional(),
  paidAt: z.iso.date().optional(),
});

export const feeAllocationQuerySchema = z.object({
  studentId: z.uuid().optional(),
  academicYearId: z.uuid().optional(),
  classId: z.uuid().optional(),
  sectionId: z.uuid().optional(),
  status: z.enum(['pending', 'partial', 'paid', 'overdue']).optional(),
});

export const feePaymentQuerySchema = z.object({
  studentId: z.uuid().optional(),
  allocationId: z.uuid().optional(),
});

export const createAdmissionApplicationSchema = z.object({
  academicYearId: z.uuid(),
  applyingForClassId: z.uuid(),
  applicantName: z.string().trim().min(2).max(100),
  dateOfBirth: z.iso.date().nullable().optional(),
  gender: z.enum(['male', 'female', 'other']).nullable().optional(),
  parentName: z.string().trim().min(2).max(100),
  parentEmail: z.string().trim().email().nullable().optional(),
  parentPhone: z.string().trim().min(7).max(20),
  address: z.string().trim().max(300).nullable().optional(),
  previousSchool: z.string().trim().max(160).nullable().optional(),
  applicationDate: z.iso.date().optional(),
  status: z.enum(['inquiry', 'applied', 'under_review', 'approved', 'enrolled', 'rejected']).default('applied'),
  notes: z.string().trim().max(500).nullable().optional(),
  documents: z
    .array(
      z.object({
        title: z.string().trim().min(2).max(120),
        status: z.enum(['pending', 'submitted', 'verified', 'rejected']).default('pending'),
        documentNumber: z.string().trim().max(60).nullable().optional(),
        notes: z.string().trim().max(200).nullable().optional(),
      }),
    )
    .optional(),
});

export const updateAdmissionApplicationSchema = createAdmissionApplicationSchema.partial().extend({
  decisionDate: z.iso.date().nullable().optional(),
});

export const enrollApplicantSchema = z.object({
  sectionId: z.uuid(),
  admissionNumber: z.string().trim().min(2).max(32).optional(),
  rollNumber: z.string().trim().max(16).optional(),
});

export const admissionQuerySchema = z.object({
  academicYearId: z.uuid().optional(),
  classId: z.uuid().optional(),
  status: z.enum(['inquiry', 'applied', 'under_review', 'approved', 'enrolled', 'rejected']).optional(),
  search: z.string().trim().max(100).optional(),
});

export const addAdmissionDocumentSchema = z.object({
  title: z.string().trim().min(2).max(120),
  status: z.enum(['pending', 'submitted', 'verified', 'rejected']).default('pending'),
  documentNumber: z.string().trim().max(60).nullable().optional(),
  notes: z.string().trim().max(200).nullable().optional(),
});

export const updateAdmissionDocumentSchema = addAdmissionDocumentSchema.partial();

export const createPaymentOrderSchema = z.object({
  allocationId: z.uuid(),
  amount: z.number().int().positive(),
  returnUrl: z.string().url().optional(),
});

export const verifyPaymentOrderSchema = z.object({
  orderId: z.string().trim().min(1).max(100),
});



