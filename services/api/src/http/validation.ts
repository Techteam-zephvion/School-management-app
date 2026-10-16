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
  quotaCategory: z.enum(['general', 'rte', 'sibling', 'staff_child', 'management']).default('general'),
  casteCategory: z.enum(['general', 'obc', 'sc', 'st', 'ews']).default('general'),
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
  quotaCategory: z.enum(['general', 'rte', 'sibling', 'staff_child', 'management']).optional(),
  search: z.string().trim().max(100).optional(),
});

export const addAdmissionDocumentSchema = z.object({
  title: z.string().trim().min(2).max(120),
  status: z.enum(['pending', 'submitted', 'verified', 'rejected']).default('pending'),
  documentNumber: z.string().trim().max(60).nullable().optional(),
  fileKey: z.string().trim().nullable().optional(),
  fileUrl: z.string().trim().nullable().optional(),
  fileName: z.string().trim().nullable().optional(),
  fileSize: z.number().int().nonnegative().nullable().optional(),
  mimeType: z.string().trim().nullable().optional(),
  notes: z.string().trim().max(200).nullable().optional(),
});

export const updateAdmissionDocumentSchema = addAdmissionDocumentSchema.partial();

export const attachAdmissionDocumentFileSchema = z.object({
  fileKey: z.string().trim().min(5).max(500),
  fileUrl: z.string().trim().min(1).max(500),
  fileName: z.string().trim().min(1).max(255),
  fileSize: z.number().int().nonnegative(),
  mimeType: z.string().trim().min(1).max(100),
});

export const createPaymentOrderSchema = z.object({
  allocationId: z.uuid(),
  amount: z.number().int().positive(),
  returnUrl: z.string().url().optional(),
});

export const verifyPaymentOrderSchema = z.object({
  orderId: z.string().trim().min(1).max(100),
});

export const bulkImportPreviewSchema = z.object({
  entity: z.enum(['students', 'staff', 'classes_sections']),
  csv: z.string().min(1, 'CSV content is required'),
});

export const bulkImportCommitSchema = z.object({
  entity: z.enum(['students', 'staff', 'classes_sections']),
  academicYearId: z.string().uuid().optional(),
  defaultClassId: z.string().uuid().optional(),
  defaultSectionId: z.string().uuid().optional(),
  records: z.array(z.record(z.string(), z.unknown())).min(1, 'At least one record is required to commit'),
});

export const onboardingWizardSchema = z.object({
  schoolName: z.string().trim().min(2).max(120),
  academicYearName: z.string().trim().min(2).max(60),
  startDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Invalid startDate (YYYY-MM-DD)'),
  endDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Invalid endDate (YYYY-MM-DD)'),
  classes: z
    .array(
      z.object({
        name: z.string().trim().min(1).max(60),
        sections: z.array(z.string().trim().min(1).max(30)).min(1),
      }),
    )
    .min(1, 'At least one class is required'),
});

export const sendNotificationSchema = z.object({
  recipientUserId: z.string().uuid().optional().nullable(),
  recipientPhone: z.string().trim().optional().nullable(),
  recipientEmail: z.string().trim().email().optional().nullable(),
  channel: z.enum(['whatsapp', 'sms', 'push', 'in_app']),
  templateId: z.string().trim().optional().nullable(),
  title: z.string().trim().min(1).max(200),
  body: z.string().trim().min(1).max(2000),
  data: z.record(z.string(), z.unknown()).optional().nullable(),
});

export const notificationQuerySchema = z.object({
  channel: z.enum(['whatsapp', 'sms', 'push', 'in_app']).optional(),
  status: z.enum(['queued', 'sent', 'delivered', 'failed']).optional(),
  limit: z.coerce.number().int().min(1).max(100).default(50),
});

export const createChatConversationSchema = z.object({
  studentId: z.string().uuid(),
  teacherStaffId: z.string().uuid(),
  subject: z.string().trim().min(2).max(160),
  initialMessage: z.string().trim().min(1).max(2000).optional(),
});

export const sendChatMessageSchema = z.object({
  content: z.string().trim().min(1).max(2000),
});

export const updateTeacherAvailabilitySchema = z.object({
  startTime: z.string().trim().regex(/^([01]\d|2[0-3]):[0-5]\d$/, 'Invalid time format HH:MM'),
  endTime: z.string().trim().regex(/^([01]\d|2[0-3]):[0-5]\d$/, 'Invalid time format HH:MM'),
  availableDays: z.string().trim().min(1).max(20),
  autoReplyMessage: z.string().trim().min(1).max(500),
  isEnabled: z.boolean(),
});

// Phase 11: Enterprise Roles & Class Teacher Assignment
export const assignSectionClassTeacherSchema = z.object({
  classTeacherStaffId: z.string().uuid().nullable(),
});

// Phase 11: DPDP Act 2023 Compliance
export const recordConsentSchema = z.object({
  studentId: z.string().uuid(),
  parentGuardianName: z.string().trim().min(2).max(120),
  parentGuardianPhone: z.string().trim().min(10).max(20),
  consentType: z.string().trim().min(2).max(80),
  verifiedVia: z.enum(['portal_submission', 'signed_form', 'sms_otp']).default('portal_submission'),
  validUntil: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Invalid date format (YYYY-MM-DD)').optional(),
});

export const createDsrRequestSchema = z.object({
  studentId: z.string().uuid().optional().nullable(),
  requestType: z.enum(['data_access', 'data_rectification', 'data_erasure_anonymization']),
  reason: z.string().trim().min(5).max(1000),
});

export const resolveDsrRequestSchema = z.object({
  status: z.enum(['fulfilled', 'rejected', 'in_review']),
  resolutionNotes: z.string().trim().min(2).max(1000),
  anonymizeStudent: z.boolean().optional(),
});

export const auditLogQuerySchema = z.object({
  action: z.string().trim().optional(),
  resourceType: z.string().trim().optional(),
  limit: z.coerce.number().int().min(1).max(100).default(50),
});

// Phase 11: Financial Depth (Concessions, Refunds, Heads)
export const createFeeConcessionSchema = z.object({
  name: z.string().trim().min(2).max(120),
  code: z.string().trim().min(2).max(40),
  type: z.enum(['percentage', 'flat']),
  value: z.number().int().min(1),
  category: z.enum(['merit', 'sibling', 'staff_ward', 'financial_aid', 'sports']).default('merit'),
});

export const applyStudentConcessionSchema = z.object({
  studentId: z.string().uuid(),
  allocationId: z.string().uuid(),
  concessionId: z.string().uuid(),
  reason: z.string().trim().max(300).optional(),
});

export const createFeeRefundSchema = z.object({
  allocationId: z.string().uuid(),
  studentId: z.string().uuid(),
  paymentId: z.string().uuid().optional().nullable(),
  amount: z.number().int().min(1),
  reason: z.string().trim().min(3).max(500),
  mode: z.enum(['bank_transfer', 'cash', 'cheque', 'gateway_refund']).default('bank_transfer'),
  referenceNumber: z.string().trim().max(100).optional().nullable(),
});

export const updateRefundStatusSchema = z.object({
  status: z.enum(['approved', 'processed', 'rejected']),
});

export const createFeeStructureHeadSchema = z.object({
  feeStructureId: z.string().uuid(),
  headName: z.string().trim().min(2).max(80),
  amount: z.number().int().min(0),
  isOptional: z.boolean().default(false),
});

// Phase 12: School Operations & Daily Differentiators

export const createStudentLeaveSchema = z.object({
  studentId: z.uuid().optional(),
  startDate: z.iso.date(),
  endDate: z.iso.date(),
  reason: z.string().trim().min(2).max(500),
  documentUrl: z.string().trim().url().nullable().optional(),
});

export const updateStudentLeaveStatusSchema = z.object({
  status: z.enum(['approved', 'rejected']),
  reviewerNotes: z.string().trim().max(300).nullable().optional(),
});

export const createStaffLeaveSchema = z.object({
  staffId: z.uuid().optional(),
  leaveType: z.enum(['casual', 'sick', 'earned', 'maternity_paternity', 'unpaid']).default('casual'),
  startDate: z.iso.date(),
  endDate: z.iso.date(),
  reason: z.string().trim().min(2).max(500),
});

export const updateStaffLeaveStatusSchema = z.object({
  status: z.enum(['approved', 'rejected']),
  reviewerNotes: z.string().trim().max(300).nullable().optional(),
});

export const createTransportVehicleSchema = z.object({
  vehicleNumber: z.string().trim().min(2).max(30),
  model: z.string().trim().min(2).max(60),
  capacity: z.number().int().positive(),
  insuranceExpiry: z.iso.date().nullable().optional(),
  pollutionExpiry: z.iso.date().nullable().optional(),
  status: z.enum(['active', 'maintenance', 'retired']).default('active'),
});

export const createTransportDriverSchema = z.object({
  fullName: z.string().trim().min(2).max(100),
  phone: z.string().trim().min(7).max(20),
  licenseNumber: z.string().trim().min(3).max(50),
  licenseExpiry: z.iso.date().nullable().optional(),
  status: z.enum(['active', 'on_leave', 'inactive']).default('active'),
});

export const createTransportRouteSchema = z.object({
  routeNumber: z.string().trim().min(1).max(20),
  routeName: z.string().trim().min(2).max(100),
  startPoint: z.string().trim().min(2).max(120),
  endPoint: z.string().trim().min(2).max(120),
  vehicleId: z.uuid().nullable().optional(),
  driverId: z.uuid().nullable().optional(),
  status: z.enum(['active', 'inactive']).default('active'),
});

export const createTransportStopSchema = z.object({
  routeId: z.uuid(),
  stopName: z.string().trim().min(2).max(100),
  pickupTime: z.string().trim().regex(/^\d{1,2}:\d{2}$/, 'Invalid time (HH:MM)'),
  dropTime: z.string().trim().regex(/^\d{1,2}:\d{2}$/, 'Invalid time (HH:MM)'),
  stopOrder: z.number().int().default(1),
  monthlyFeeAmount: z.number().int().default(0),
  latitude: z.union([z.string(), z.number().transform((n) => String(n))]).optional(),
  longitude: z.union([z.string(), z.number().transform((n) => String(n))]).optional(),
});

export const createTransportAllocationSchema = z.object({
  studentId: z.uuid(),
  routeId: z.uuid(),
  stopId: z.uuid(),
  academicYearId: z.uuid().optional(),
  startDate: z.iso.date().optional(),
  endDate: z.iso.date().nullable().optional(),
});

export const createTransportLogSchema = z.object({
  routeId: z.uuid(),
  date: z.iso.date().optional(),
  tripType: z.enum(['pickup', 'drop']),
  status: z.enum(['scheduled', 'in_transit', 'completed', 'delayed']).default('scheduled'),
  currentStopId: z.uuid().nullable().optional(),
  notes: z.string().trim().max(300).nullable().optional(),
});

export const issueCertificateSchema = z.object({
  studentId: z.uuid(),
  certificateType: z.enum(['transfer_certificate', 'bonafide', 'character_conduct']),
  academicYearId: z.uuid().optional(),
  issueDate: z.iso.date().optional(),
  metadata: z.record(z.string(), z.unknown()).optional(),
});

export const revokeCertificateSchema = z.object({
  reason: z.string().trim().max(300).optional(),
});

export const publicInquirySchema = z.object({
  schoolCode: z.string().trim().min(1),
  applicantName: z.string().trim().min(2).max(100),
  dateOfBirth: z.iso.date().nullable().optional(),
  gender: z.enum(['male', 'female', 'other']).nullable().optional(),
  parentName: z.string().trim().min(2).max(100),
  parentEmail: z.string().trim().email().nullable().optional(),
  parentPhone: z.string().trim().min(7).max(20),
  applyingForClassId: z.uuid().nullable().optional(),
  address: z.string().trim().max(300).nullable().optional(),
  previousSchool: z.string().trim().max(160).nullable().optional(),
  quotaCategory: z.enum(['general', 'rte', 'sibling', 'staff_child', 'management']).default('general'),
  casteCategory: z.enum(['general', 'obc', 'sc', 'st', 'ews']).default('general'),
  notes: z.string().trim().max(500).nullable().optional(),
});

export const createCalendarEventSchema = z.object({
  academicYearId: z.uuid().optional(),
  title: z.string().trim().min(2).max(120),
  description: z.string().trim().max(500).nullable().optional(),
  eventType: z.enum(['holiday', 'exam', 'sports', 'cultural', 'ptm', 'meeting', 'other']).default('holiday'),
  startDate: z.iso.date(),
  endDate: z.iso.date(),
  isAllDay: z.boolean().default(true),
  targetAudience: z.enum(['all', 'teachers', 'students', 'parents']).default('all'),
});

export const createPtmScheduleSchema = z.object({
  academicYearId: z.uuid().optional(),
  title: z.string().trim().min(2).max(120),
  eventDate: z.iso.date(),
  startTime: z.string().trim().regex(/^\d{1,2}:\d{2}$/, 'Invalid time (HH:MM)'),
  endTime: z.string().trim().regex(/^\d{1,2}:\d{2}$/, 'Invalid time (HH:MM)'),
  slotDurationMinutes: z.number().int().min(5).max(60).default(15),
  teacherStaffIds: z.array(z.uuid()).optional(),
});

export const bookPtmSlotSchema = z.object({
  slotId: z.uuid(),
  studentId: z.uuid().optional(),
  parentNotes: z.string().trim().max(300).nullable().optional(),
});

export const updatePtmSlotNotesSchema = z.object({
  teacherNotes: z.string().trim().max(500).optional(),
  status: z.enum(['available', 'booked', 'completed', 'cancelled']).optional(),
});

