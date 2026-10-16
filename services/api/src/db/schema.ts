import {
  boolean,
  date,
  index,
  integer,
  jsonb,
  pgEnum,
  pgTable,
  text,
  time,
  timestamp,
  unique,
  uniqueIndex,
  uuid,
} from 'drizzle-orm/pg-core';

export const roleEnum = pgEnum('role', [
  'admin',
  'teacher',
  'student',
  'parent',
  'accountant',
  'admissions_officer',
  'principal',
]);
export const attendanceKindEnum = pgEnum('attendance_kind', ['daily', 'period']);
export const attendanceStatusEnum = pgEnum('attendance_status', [
  'present',
  'absent',
  'late',
  'excused',
]);
export const teachingMaterialTypeEnum = pgEnum('teaching_material_type', ['lesson_plan', 'worksheet', 'quiz']);
export const announcementAudienceEnum = pgEnum('announcement_audience', ['school', 'class_section']);
export const announcementPriorityEnum = pgEnum('announcement_priority', ['normal', 'important', 'urgent']);
export const homeworkStatusEnum = pgEnum('homework_status', ['draft', 'published', 'archived']);
export const homeworkSubmissionStatusEnum = pgEnum('homework_submission_status', [
  'submitted',
  'reviewed',
  'resubmitted',
]);
export const examStatusEnum = pgEnum('exam_status', ['draft', 'published', 'archived']);
export const feeFrequencyEnum = pgEnum('fee_frequency', ['one_time', 'term', 'monthly', 'annual']);
export const feeAllocationStatusEnum = pgEnum('fee_allocation_status', ['pending', 'partial', 'paid', 'overdue']);
export const feePaymentMethodEnum = pgEnum('fee_payment_method', ['cash', 'upi', 'card', 'bank_transfer', 'cheque']);
export const admissionStatusEnum = pgEnum('admission_status', [
  'inquiry',
  'applied',
  'under_review',
  'approved',
  'enrolled',
  'rejected',
]);
export const paymentOrderStatusEnum = pgEnum('payment_order_status', ['ACTIVE', 'PAID', 'EXPIRED', 'FAILED']);
export const documentStatusEnum = pgEnum('document_status', [
  'pending',
  'submitted',
  'verified',
  'rejected',
]);
export const notificationChannelEnum = pgEnum('notification_channel', ['whatsapp', 'sms', 'push', 'in_app']);
export const notificationStatusEnum = pgEnum('notification_status', ['queued', 'sent', 'delivered', 'failed']);
export const chatConversationStatusEnum = pgEnum('chat_conversation_status', ['active', 'closed', 'archived']);
export const consentStatusEnum = pgEnum('consent_status', ['granted', 'revoked', 'expired']);
export const dsrStatusEnum = pgEnum('dsr_status', ['pending', 'in_review', 'fulfilled', 'rejected']);
export const concessionTypeEnum = pgEnum('concession_type', ['percentage', 'flat']);
export const feeRefundStatusEnum = pgEnum('fee_refund_status', ['pending', 'approved', 'processed', 'rejected']);
export const leaveTypeEnum = pgEnum('leave_type', [
  'casual',
  'sick',
  'earned',
  'maternity_paternity',
  'unpaid',
]);
export const leaveStatusEnum = pgEnum('leave_status', [
  'pending',
  'approved',
  'rejected',
]);
export const certificateTypeEnum = pgEnum('certificate_type', [
  'transfer_certificate',
  'bonafide',
  'character_conduct',
]);
export const certificateStatusEnum = pgEnum('certificate_status', [
  'valid',
  'revoked',
]);
export const calendarEventTypeEnum = pgEnum('calendar_event_type', [
  'holiday',
  'exam',
  'sports',
  'cultural',
  'ptm',
  'meeting',
  'other',
]);
export const ptmStatusEnum = pgEnum('ptm_status', [
  'scheduled',
  'in_progress',
  'completed',
  'cancelled',
]);
export const ptmSlotStatusEnum = pgEnum('ptm_slot_status', [
  'available',
  'booked',
  'completed',
  'cancelled',
]);

export const gradingBoardEnum = pgEnum('grading_board', [
  'cbse',
  'icse',
  'state_board',
  'cambridge',
  'custom',
]);

export const assessmentComponentTypeEnum = pgEnum('assessment_component_type', [
  'periodic_test',
  'multiple_assessment',
  'portfolio',
  'subject_enrichment',
  'term_exam',
  'internal_assessment',
  'board_exam',
  'formative_assessment',
  'summative_assessment',
  'practical',
]);

export const gradingTermEnum = pgEnum('grading_term', [
  'term_1',
  'term_2',
  'annual',
  'all_terms',
]);

export const reportCardResultStatusEnum = pgEnum('report_card_result_status', [
  'passed',
  'promoted',
  'compartment',
  'failed',
  'under_review',
]);

export const offlineSyncStatusEnum = pgEnum('offline_sync_status', [
  'success',
  'partial_conflict',
  'failed',
]);


const timestamps = {
  createdAt: timestamp('created_at', { withTimezone: true }).defaultNow().notNull(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).defaultNow().notNull(),
};

export const schools = pgTable('schools', {
  id: uuid('id').primaryKey().defaultRandom(),
  name: text('name').notNull(),
  code: text('code').notNull().unique(),
  ...timestamps,
});

export const academicYears = pgTable(
  'academic_years',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    schoolId: uuid('school_id').notNull().references(() => schools.id, { onDelete: 'cascade' }),
    name: text('name').notNull(),
    startsOn: date('starts_on').notNull(),
    endsOn: date('ends_on').notNull(),
    isActive: boolean('is_active').default(false).notNull(),
    ...timestamps,
  },
  (table) => [unique().on(table.schoolId, table.name)],
);

export const appUsers = pgTable('app_users', {
  id: uuid('id').primaryKey().defaultRandom(),
  schoolId: uuid('school_id').notNull().references(() => schools.id, { onDelete: 'cascade' }),
  neonUserId: text('neon_user_id').notNull().unique(),
  email: text('email').notNull(),
  displayName: text('display_name').notNull(),
  isActive: boolean('is_active').default(true).notNull(),
  ...timestamps,
});

export const userRoles = pgTable(
  'user_roles',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    userId: uuid('user_id').notNull().references(() => appUsers.id, { onDelete: 'cascade' }),
    role: roleEnum('role').notNull(),
    ...timestamps,
  },
  (table) => [unique().on(table.userId, table.role)],
);

export const staff = pgTable('staff', {
  id: uuid('id').primaryKey().defaultRandom(),
  schoolId: uuid('school_id').notNull().references(() => schools.id, { onDelete: 'cascade' }),
  userId: uuid('user_id').references(() => appUsers.id, { onDelete: 'set null' }),
  staffCode: text('staff_code').notNull(),
  fullName: text('full_name').notNull(),
  email: text('email').notNull(),
  phone: text('phone'),
  isTeacher: boolean('is_teacher').default(false).notNull(),
  ...timestamps,
}, (table) => [unique().on(table.schoolId, table.staffCode)]);

export const classes = pgTable(
  'classes',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    schoolId: uuid('school_id').notNull().references(() => schools.id, { onDelete: 'cascade' }),
    name: text('name').notNull(),
    sortOrder: integer('sort_order').default(0).notNull(),
    ...timestamps,
  },
  (table) => [unique().on(table.schoolId, table.name)],
);

export const sections = pgTable(
  'sections',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    schoolId: uuid('school_id').notNull().references(() => schools.id, { onDelete: 'cascade' }),
    classId: uuid('class_id').notNull().references(() => classes.id, { onDelete: 'cascade' }),
    name: text('name').notNull(),
    classTeacherStaffId: uuid('class_teacher_staff_id').references(() => staff.id, { onDelete: 'set null' }),
    ...timestamps,
  },
  (table) => [unique().on(table.classId, table.name)],
);

export const subjects = pgTable(
  'subjects',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    schoolId: uuid('school_id').notNull().references(() => schools.id, { onDelete: 'cascade' }),
    name: text('name').notNull(),
    code: text('code').notNull(),
    ...timestamps,
  },
  (table) => [unique().on(table.schoolId, table.code)],
);

export const students = pgTable(
  'students',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    schoolId: uuid('school_id').notNull().references(() => schools.id, { onDelete: 'cascade' }),
    userId: uuid('user_id').references(() => appUsers.id, { onDelete: 'set null' }),
    admissionNumber: text('admission_number').notNull(),
    fullName: text('full_name').notNull(),
    guardianName: text('guardian_name'),
    guardianPhone: text('guardian_phone'),
    isActive: boolean('is_active').default(true).notNull(),
    ...timestamps,
  },
  (table) => [
    unique().on(table.schoolId, table.admissionNumber),
    index('students_user_idx').on(table.schoolId, table.userId),
  ],
);

export const studentGuardians = pgTable(
  'student_guardians',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    schoolId: uuid('school_id').notNull().references(() => schools.id, { onDelete: 'cascade' }),
    studentId: uuid('student_id').notNull().references(() => students.id, { onDelete: 'cascade' }),
    appUserId: uuid('app_user_id').notNull().references(() => appUsers.id, { onDelete: 'cascade' }),
    relationship: text('relationship').default('guardian').notNull(),
    ...timestamps,
  },
  (table) => [
    unique().on(table.studentId, table.appUserId),
    index('student_guardians_user_idx').on(table.schoolId, table.appUserId),
    index('student_guardians_student_idx').on(table.schoolId, table.studentId),
  ],
);

export const studentEnrollments = pgTable(
  'student_enrollments',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    schoolId: uuid('school_id').notNull().references(() => schools.id, { onDelete: 'cascade' }),
    studentId: uuid('student_id').notNull().references(() => students.id, { onDelete: 'cascade' }),
    academicYearId: uuid('academic_year_id').notNull().references(() => academicYears.id),
    classId: uuid('class_id').notNull().references(() => classes.id),
    sectionId: uuid('section_id').notNull().references(() => sections.id),
    rollNumber: text('roll_number'),
    ...timestamps,
  },
  (table) => [unique().on(table.studentId, table.academicYearId)],
);

export const teacherAssignments = pgTable(
  'teacher_assignments',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    schoolId: uuid('school_id').notNull().references(() => schools.id, { onDelete: 'cascade' }),
    staffId: uuid('staff_id').notNull().references(() => staff.id, { onDelete: 'cascade' }),
    academicYearId: uuid('academic_year_id').notNull().references(() => academicYears.id),
    classId: uuid('class_id').notNull().references(() => classes.id),
    sectionId: uuid('section_id').notNull().references(() => sections.id),
    subjectId: uuid('subject_id').references(() => subjects.id),
    canTakeDailyAttendance: boolean('can_take_daily_attendance').default(false).notNull(),
    ...timestamps,
  },
  (table) => [unique().on(table.staffId, table.academicYearId, table.sectionId, table.subjectId)],
);

export const attendanceSessions = pgTable(
  'attendance_sessions',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    schoolId: uuid('school_id').notNull().references(() => schools.id, { onDelete: 'cascade' }),
    academicYearId: uuid('academic_year_id').notNull().references(() => academicYears.id),
    classId: uuid('class_id').notNull().references(() => classes.id),
    sectionId: uuid('section_id').notNull().references(() => sections.id),
    subjectId: uuid('subject_id').references(() => subjects.id),
    takenByStaffId: uuid('taken_by_staff_id').notNull().references(() => staff.id),
    kind: attendanceKindEnum('kind').notNull(),
    attendanceDate: date('attendance_date').notNull(),
    periodNumber: integer('period_number'),
    notes: text('notes'),
    ...timestamps,
  },
  (table) => [
    unique().on(
      table.schoolId,
      table.academicYearId,
      table.sectionId,
      table.kind,
      table.attendanceDate,
      table.periodNumber,
      table.subjectId,
    ),
  ],
);

export const timetableEntries = pgTable(
  'timetable_entries',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    schoolId: uuid('school_id').notNull().references(() => schools.id, { onDelete: 'cascade' }),
    academicYearId: uuid('academic_year_id').notNull().references(() => academicYears.id),
    classId: uuid('class_id').notNull().references(() => classes.id),
    sectionId: uuid('section_id').notNull().references(() => sections.id),
    subjectId: uuid('subject_id').notNull().references(() => subjects.id),
    staffId: uuid('staff_id').notNull().references(() => staff.id),
    dayOfWeek: integer('day_of_week').notNull(),
    startTime: time('start_time').notNull(),
    endTime: time('end_time').notNull(),
    periodNumber: integer('period_number'),
    label: text('label'),
    ...timestamps,
  },
  (table) => [
    unique().on(
      table.schoolId,
      table.academicYearId,
      table.sectionId,
      table.dayOfWeek,
      table.startTime,
      table.endTime,
    ),
    index('timetable_entries_teacher_day_idx').on(table.schoolId, table.academicYearId, table.staffId, table.dayOfWeek),
    index('timetable_entries_section_day_idx').on(table.schoolId, table.academicYearId, table.sectionId, table.dayOfWeek),
  ],
);

export const attendanceRecords = pgTable(
  'attendance_records',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    schoolId: uuid('school_id').notNull().references(() => schools.id, { onDelete: 'cascade' }),
    sessionId: uuid('session_id').notNull().references(() => attendanceSessions.id, { onDelete: 'cascade' }),
    studentId: uuid('student_id').notNull().references(() => students.id, { onDelete: 'cascade' }),
    status: attendanceStatusEnum('status').notNull(),
    remarks: text('remarks'),
    ...timestamps,
  },
  (table) => [unique().on(table.sessionId, table.studentId)],
);

export const teacherMaterials = pgTable(
  'teacher_materials',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    schoolId: uuid('school_id').notNull().references(() => schools.id, { onDelete: 'cascade' }),
    ownerStaffId: uuid('owner_staff_id').notNull().references(() => staff.id, { onDelete: 'cascade' }),
    academicYearId: uuid('academic_year_id').references(() => academicYears.id),
    classId: uuid('class_id').references(() => classes.id),
    sectionId: uuid('section_id').references(() => sections.id),
    subjectId: uuid('subject_id').references(() => subjects.id),
    type: teachingMaterialTypeEnum('type').notNull(),
    title: text('title').notNull(),
    topic: text('topic').notNull(),
    difficulty: text('difficulty').notNull(),
    language: text('language').default('English').notNull(),
    durationMinutes: integer('duration_minutes'),
    questionCount: integer('question_count'),
    content: jsonb('content').$type<Record<string, unknown>>().notNull(),
    metadata: jsonb('metadata').$type<Record<string, unknown>>().default({}).notNull(),
    ...timestamps,
  },
  (table) => [
    index('teacher_materials_owner_idx').on(table.schoolId, table.ownerStaffId, table.updatedAt),
    index('teacher_materials_context_idx').on(table.schoolId, table.classId, table.sectionId, table.subjectId),
  ],
);

export const aiUsageEvents = pgTable(
  'ai_usage_events',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    schoolId: uuid('school_id').notNull().references(() => schools.id, { onDelete: 'cascade' }),
    appUserId: uuid('app_user_id').notNull().references(() => appUsers.id, { onDelete: 'cascade' }),
    staffId: uuid('staff_id').references(() => staff.id, { onDelete: 'set null' }),
    feature: text('feature').notNull(),
    generationType: text('generation_type'),
    status: text('status').notNull(),
    latencyMs: integer('latency_ms'),
    inputTokens: integer('input_tokens'),
    outputTokens: integer('output_tokens'),
    totalTokens: integer('total_tokens'),
    model: text('model'),
    errorCategory: text('error_category'),
    createdAt: timestamp('created_at', { withTimezone: true }).defaultNow().notNull(),
  },
  (table) => [
    index('ai_usage_events_school_created_idx').on(table.schoolId, table.createdAt),
    index('ai_usage_events_user_created_idx').on(table.schoolId, table.appUserId, table.createdAt),
    index('ai_usage_events_feature_idx').on(table.schoolId, table.feature, table.generationType),
  ],
);

export const announcements = pgTable(
  'announcements',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    schoolId: uuid('school_id').notNull().references(() => schools.id, { onDelete: 'cascade' }),
    authorUserId: uuid('author_user_id').notNull().references(() => appUsers.id, { onDelete: 'cascade' }),
    authorStaffId: uuid('author_staff_id').references(() => staff.id, { onDelete: 'set null' }),
    audience: announcementAudienceEnum('audience').notNull(),
    priority: announcementPriorityEnum('priority').default('normal').notNull(),
    classId: uuid('class_id').references(() => classes.id, { onDelete: 'set null' }),
    sectionId: uuid('section_id').references(() => sections.id, { onDelete: 'set null' }),
    title: text('title').notNull(),
    body: text('body').notNull(),
    publishedAt: timestamp('published_at', { withTimezone: true }).defaultNow().notNull(),
    expiresAt: timestamp('expires_at', { withTimezone: true }),
    ...timestamps,
  },
  (table) => [
    index('announcements_school_published_idx').on(table.schoolId, table.publishedAt),
    index('announcements_section_published_idx').on(table.schoolId, table.classId, table.sectionId, table.publishedAt),
  ],
);

export const homeworkAssignments = pgTable(
  'homework_assignments',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    schoolId: uuid('school_id').notNull().references(() => schools.id, { onDelete: 'cascade' }),
    ownerStaffId: uuid('owner_staff_id').notNull().references(() => staff.id, { onDelete: 'cascade' }),
    academicYearId: uuid('academic_year_id').notNull().references(() => academicYears.id),
    classId: uuid('class_id').notNull().references(() => classes.id),
    sectionId: uuid('section_id').notNull().references(() => sections.id),
    subjectId: uuid('subject_id').references(() => subjects.id),
    title: text('title').notNull(),
    instructions: text('instructions').notNull(),
    dueDate: date('due_date').notNull(),
    estimatedMinutes: integer('estimated_minutes'),
    status: homeworkStatusEnum('status').default('published').notNull(),
    sourceMaterialId: uuid('source_material_id').references(() => teacherMaterials.id, { onDelete: 'set null' }),
    ...timestamps,
  },
  (table) => [
    index('homework_assignments_teacher_idx').on(table.schoolId, table.ownerStaffId, table.dueDate),
    index('homework_assignments_section_idx').on(table.schoolId, table.academicYearId, table.sectionId, table.dueDate),
  ],
);

export const homeworkSubmissions = pgTable(
  'homework_submissions',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    schoolId: uuid('school_id').notNull().references(() => schools.id, { onDelete: 'cascade' }),
    assignmentId: uuid('assignment_id').notNull().references(() => homeworkAssignments.id, { onDelete: 'cascade' }),
    studentId: uuid('student_id').notNull().references(() => students.id, { onDelete: 'cascade' }),
    content: text('content').notNull(),
    attachmentUrl: text('attachment_url'),
    status: homeworkSubmissionStatusEnum('status').default('submitted').notNull(),
    marksObtained: integer('marks_obtained'),
    teacherFeedback: text('teacher_feedback'),
    reviewedByStaffId: uuid('reviewed_by_staff_id').references(() => staff.id, { onDelete: 'set null' }),
    submittedAt: timestamp('submitted_at', { withTimezone: true }).defaultNow().notNull(),
    reviewedAt: timestamp('reviewed_at', { withTimezone: true }),
    ...timestamps,
  },
  (table) => [
    uniqueIndex('homework_submissions_assignment_student_idx').on(table.assignmentId, table.studentId),
    index('homework_submissions_school_assignment_idx').on(table.schoolId, table.assignmentId),
    index('homework_submissions_student_idx').on(table.studentId),
  ],
);

export const exams = pgTable(
  'exams',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    schoolId: uuid('school_id').notNull().references(() => schools.id, { onDelete: 'cascade' }),
    academicYearId: uuid('academic_year_id').notNull().references(() => academicYears.id),
    classId: uuid('class_id').notNull().references(() => classes.id),
    sectionId: uuid('section_id').notNull().references(() => sections.id),
    subjectId: uuid('subject_id').references(() => subjects.id),
    name: text('name').notNull(),
    examDate: date('exam_date').notNull(),
    maxMarks: integer('max_marks').notNull(),
    status: examStatusEnum('status').default('draft').notNull(),
    ...timestamps,
  },
  (table) => [
    index('exams_section_idx').on(table.schoolId, table.academicYearId, table.sectionId, table.examDate),
    index('exams_subject_idx').on(table.schoolId, table.subjectId, table.examDate),
  ],
);

export const examMarks = pgTable(
  'exam_marks',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    schoolId: uuid('school_id').notNull().references(() => schools.id, { onDelete: 'cascade' }),
    examId: uuid('exam_id').notNull().references(() => exams.id, { onDelete: 'cascade' }),
    studentId: uuid('student_id').notNull().references(() => students.id, { onDelete: 'cascade' }),
    recordedByStaffId: uuid('recorded_by_staff_id').notNull().references(() => staff.id),
    marksObtained: integer('marks_obtained').notNull(),
    remarks: text('remarks'),
    ...timestamps,
  },
  (table) => [
    unique().on(table.examId, table.studentId),
    index('exam_marks_student_idx').on(table.schoolId, table.studentId),
  ],
);

export const feeStructures = pgTable(
  'fee_structures',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    schoolId: uuid('school_id').notNull().references(() => schools.id, { onDelete: 'cascade' }),
    academicYearId: uuid('academic_year_id').notNull().references(() => academicYears.id),
    name: text('name').notNull(),
    code: text('code').notNull(),
    description: text('description'),
    amount: integer('amount').notNull(),
    frequency: feeFrequencyEnum('frequency').default('term').notNull(),
    dueDate: date('due_date'),
    lateFeeGracePeriodDays: integer('late_fee_grace_period_days').default(0).notNull(),
    lateFeeType: text('late_fee_type').default('none').notNull(),
    lateFeeAmount: integer('late_fee_amount').default(0).notNull(),
    ...timestamps,
  },
  (table) => [
    unique().on(table.schoolId, table.academicYearId, table.code),
    index('fee_structures_school_year_idx').on(table.schoolId, table.academicYearId),
  ],
);

export const studentFeeAllocations = pgTable(
  'student_fee_allocations',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    schoolId: uuid('school_id').notNull().references(() => schools.id, { onDelete: 'cascade' }),
    studentId: uuid('student_id').notNull().references(() => students.id, { onDelete: 'cascade' }),
    feeStructureId: uuid('fee_structure_id').notNull().references(() => feeStructures.id, { onDelete: 'cascade' }),
    academicYearId: uuid('academic_year_id').notNull().references(() => academicYears.id),
    amount: integer('amount').notNull(),
    dueDate: date('due_date').notNull(),
    status: feeAllocationStatusEnum('status').default('pending').notNull(),
    ...timestamps,
  },
  (table) => [
    index('fee_allocations_student_idx').on(table.schoolId, table.studentId),
    index('fee_allocations_year_status_idx').on(table.schoolId, table.academicYearId, table.status),
  ],
);

export const feePayments = pgTable(
  'fee_payments',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    schoolId: uuid('school_id').notNull().references(() => schools.id, { onDelete: 'cascade' }),
    allocationId: uuid('allocation_id').notNull().references(() => studentFeeAllocations.id, { onDelete: 'cascade' }),
    studentId: uuid('student_id').notNull().references(() => students.id, { onDelete: 'cascade' }),
    receiptNumber: text('receipt_number').notNull(),
    amountPaid: integer('amount_paid').notNull(),
    paymentMethod: feePaymentMethodEnum('payment_method').default('cash').notNull(),
    transactionReference: text('transaction_reference'),
    paidAt: timestamp('paid_at', { withTimezone: true }).defaultNow().notNull(),
    recordedByStaffId: uuid('recorded_by_staff_id').references(() => staff.id, { onDelete: 'set null' }),
    notes: text('notes'),
    ...timestamps,
  },
  (table) => [
    unique().on(table.schoolId, table.receiptNumber),
    index('fee_payments_student_idx').on(table.schoolId, table.studentId, table.paidAt),
    index('fee_payments_allocation_idx').on(table.schoolId, table.allocationId),
  ],
);

export const admissionApplications = pgTable(
  'admission_applications',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    schoolId: uuid('school_id').notNull().references(() => schools.id, { onDelete: 'cascade' }),
    academicYearId: uuid('academic_year_id').notNull().references(() => academicYears.id),
    applyingForClassId: uuid('applying_for_class_id').notNull().references(() => classes.id),
    applicationNumber: text('application_number').notNull(),
    applicantName: text('applicant_name').notNull(),
    dateOfBirth: date('date_of_birth'),
    gender: text('gender'),
    parentName: text('parent_name').notNull(),
    parentEmail: text('parent_email'),
    parentPhone: text('parent_phone').notNull(),
    address: text('address'),
    previousSchool: text('previous_school'),
    status: admissionStatusEnum('status').default('applied').notNull(),
    applicationDate: date('application_date').notNull(),
    decisionDate: date('decision_date'),
    enrolledStudentId: uuid('enrolled_student_id').references(() => students.id, { onDelete: 'set null' }),
    notes: text('notes'),
    quotaCategory: text('quota_category').default('general').notNull(), // 'general', 'rte', 'sibling', 'staff_child', 'management'
    casteCategory: text('caste_category').default('general').notNull(), // 'general', 'obc', 'sc', 'st', 'ews'
    ...timestamps,
  },
  (table) => [
    unique().on(table.schoolId, table.applicationNumber),
    index('admission_app_status_idx').on(table.schoolId, table.status),
    index('admission_app_year_class_idx').on(table.schoolId, table.academicYearId, table.applyingForClassId),
  ],
);

export const admissionDocuments = pgTable(
  'admission_documents',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    schoolId: uuid('school_id').notNull().references(() => schools.id, { onDelete: 'cascade' }),
    applicationId: uuid('application_id').notNull().references(() => admissionApplications.id, { onDelete: 'cascade' }),
    title: text('title').notNull(),
    status: documentStatusEnum('status').default('pending').notNull(),
    documentNumber: text('document_number'),
    fileKey: text('file_key'),
    fileUrl: text('file_url'),
    fileName: text('file_name'),
    fileSize: integer('file_size'),
    mimeType: text('mime_type'),
    verifiedByStaffId: uuid('verified_by_staff_id').references(() => staff.id, { onDelete: 'set null' }),
    notes: text('notes'),
    ...timestamps,
  },
  (table) => [
    index('admission_docs_app_idx').on(table.schoolId, table.applicationId),
  ],
);

export const paymentOrders = pgTable(
  'payment_orders',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    schoolId: uuid('school_id').notNull().references(() => schools.id, { onDelete: 'cascade' }),
    studentId: uuid('student_id').notNull().references(() => students.id, { onDelete: 'cascade' }),
    allocationId: uuid('allocation_id').notNull().references(() => studentFeeAllocations.id, { onDelete: 'cascade' }),
    gateway: text('gateway').default('cashfree').notNull(),
    gatewayOrderId: text('gateway_order_id').notNull(),
    paymentSessionId: text('payment_session_id').notNull(),
    amount: integer('amount').notNull(),
    currency: text('currency').default('INR').notNull(),
    status: paymentOrderStatusEnum('status').default('ACTIVE').notNull(),
    cfPaymentId: text('cf_payment_id'),
    paymentMethod: text('payment_method'),
    failureReason: text('failure_reason'),
    ...timestamps,
  },
  (table) => [
    unique().on(table.gatewayOrderId),
    index('payment_orders_student_idx').on(table.schoolId, table.studentId),
    index('payment_orders_allocation_idx').on(table.allocationId),
  ],
);

export const paymentWebhookEvents = pgTable(
  'payment_webhook_events',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    gateway: text('gateway').default('cashfree').notNull(),
    eventId: text('event_id').notNull(),
    eventType: text('event_type').notNull(),
    payload: jsonb('payload').notNull(),
    processedAt: timestamp('processed_at', { withTimezone: true }).defaultNow().notNull(),
  },
  (table) => [
    unique().on(table.eventId),
  ],
);

export const notifications = pgTable(
  'notifications',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    schoolId: uuid('school_id').notNull().references(() => schools.id, { onDelete: 'cascade' }),
    recipientUserId: uuid('recipient_user_id').references(() => appUsers.id, { onDelete: 'set null' }),
    recipientPhone: text('recipient_phone'),
    recipientEmail: text('recipient_email'),
    channel: notificationChannelEnum('channel').notNull(),
    templateId: text('template_id'),
    title: text('title').notNull(),
    body: text('body').notNull(),
    data: jsonb('data'),
    status: notificationStatusEnum('status').default('queued').notNull(),
    failureReason: text('failure_reason'),
    sentAt: timestamp('sent_at', { withTimezone: true }),
    deliveredAt: timestamp('delivered_at', { withTimezone: true }),
    ...timestamps,
  },
  (table) => [
    index('notifications_school_status_idx').on(table.schoolId, table.status),
    index('notifications_recipient_idx').on(table.recipientUserId),
  ],
);

export const chatConversations = pgTable(
  'chat_conversations',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    schoolId: uuid('school_id').notNull().references(() => schools.id, { onDelete: 'cascade' }),
    studentId: uuid('student_id').notNull().references(() => students.id, { onDelete: 'cascade' }),
    teacherStaffId: uuid('teacher_staff_id').notNull().references(() => staff.id, { onDelete: 'cascade' }),
    parentAppUserId: uuid('parent_app_user_id').notNull().references(() => appUsers.id, { onDelete: 'cascade' }),
    subject: text('subject').notNull(),
    status: chatConversationStatusEnum('status').default('active').notNull(),
    lastMessageAt: timestamp('last_message_at', { withTimezone: true }).defaultNow().notNull(),
    ...timestamps,
  },
  (table) => [
    index('chat_conv_school_teacher_idx').on(table.schoolId, table.teacherStaffId),
    index('chat_conv_parent_idx').on(table.parentAppUserId),
    index('chat_conv_student_idx').on(table.studentId),
  ],
);

export const chatMessages = pgTable(
  'chat_messages',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    conversationId: uuid('conversation_id').notNull().references(() => chatConversations.id, { onDelete: 'cascade' }),
    senderAppUserId: uuid('sender_app_user_id').notNull().references(() => appUsers.id, { onDelete: 'cascade' }),
    senderRole: text('sender_role').notNull(), // 'teacher' | 'parent'
    content: text('content').notNull(),
    isRead: boolean('is_read').default(false).notNull(),
    isAutoReply: boolean('is_auto_reply').default(false).notNull(),
    ...timestamps,
  },
  (table) => [
    index('chat_msg_conv_idx').on(table.conversationId, table.createdAt),
  ],
);

export const teacherAvailabilitySettings = pgTable(
  'teacher_availability_settings',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    schoolId: uuid('school_id').notNull().references(() => schools.id, { onDelete: 'cascade' }),
    staffId: uuid('staff_id').notNull().references(() => staff.id, { onDelete: 'cascade' }),
    startTime: text('start_time').default('09:00').notNull(),
    endTime: text('end_time').default('16:30').notNull(),
    availableDays: text('available_days').default('1,2,3,4,5').notNull(),
    autoReplyMessage: text('auto_reply_message').default('Thank you for reaching out. I am currently outside my teaching communication hours and will review your message when school resumes.').notNull(),
    isEnabled: boolean('is_enabled').default(true).notNull(),
    ...timestamps,
  },
  (table) => [
    unique().on(table.staffId),
    index('teacher_avail_school_idx').on(table.schoolId),
  ],
);

export const dpdpConsents = pgTable(
  'dpdp_consents',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    schoolId: uuid('school_id').notNull().references(() => schools.id, { onDelete: 'cascade' }),
    studentId: uuid('student_id').notNull().references(() => students.id, { onDelete: 'cascade' }),
    parentGuardianName: text('parent_guardian_name').notNull(),
    parentGuardianPhone: text('parent_guardian_phone').notNull(),
    consentType: text('consent_type').notNull(), // 'enrollment_data_processing' | 'biometric_attendance' | 'media_publication'
    status: consentStatusEnum('status').default('granted').notNull(),
    verifiedVia: text('verified_via').default('portal_submission').notNull(),
    ipAddress: text('ip_address'),
    validUntil: timestamp('valid_until', { withTimezone: true }),
    ...timestamps,
  },
  (table) => [
    index('dpdp_consent_student_idx').on(table.schoolId, table.studentId),
    index('dpdp_consent_status_idx').on(table.schoolId, table.status),
  ],
);

export const auditLogs = pgTable(
  'audit_logs',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    schoolId: uuid('school_id').notNull().references(() => schools.id, { onDelete: 'cascade' }),
    userId: uuid('user_id'),
    userEmail: text('user_email').notNull(),
    userRole: text('user_role').notNull(),
    action: text('action').notNull(),
    resourceType: text('resource_type').notNull(),
    resourceId: text('resource_id'),
    ipAddress: text('ip_address'),
    details: jsonb('details'),
    createdAt: timestamp('created_at', { withTimezone: true }).defaultNow().notNull(),
  },
  (table) => [
    index('audit_logs_school_created_idx').on(table.schoolId, table.createdAt),
    index('audit_logs_school_resource_idx').on(table.schoolId, table.resourceType),
    index('audit_logs_user_idx').on(table.schoolId, table.userId),
  ],
);

export const dataSubjectRequests = pgTable(
  'data_subject_requests',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    schoolId: uuid('school_id').notNull().references(() => schools.id, { onDelete: 'cascade' }),
    requesterUserId: uuid('requester_user_id').references(() => appUsers.id, { onDelete: 'set null' }),
    requesterRole: text('requester_role').notNull(),
    studentId: uuid('student_id').references(() => students.id, { onDelete: 'set null' }),
    requestType: text('request_type').notNull(), // 'data_access' | 'data_rectification' | 'data_erasure_anonymization'
    status: dsrStatusEnum('status').default('pending').notNull(),
    reason: text('reason').notNull(),
    resolutionNotes: text('resolution_notes'),
    resolvedAt: timestamp('resolved_at', { withTimezone: true }),
    resolvedByUserId: uuid('resolved_by_user_id').references(() => appUsers.id, { onDelete: 'set null' }),
    ...timestamps,
  },
  (table) => [
    index('dsr_school_status_idx').on(table.schoolId, table.status),
    index('dsr_requester_idx').on(table.schoolId, table.requesterUserId),
  ],
);

export const feeStructureHeads = pgTable(
  'fee_structure_heads',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    schoolId: uuid('school_id').notNull().references(() => schools.id, { onDelete: 'cascade' }),
    feeStructureId: uuid('fee_structure_id').notNull().references(() => feeStructures.id, { onDelete: 'cascade' }),
    headName: text('head_name').notNull(), // 'tuition', 'transport', 'examination', 'library', 'sports', 'lab', 'uniform'
    amount: integer('amount').notNull(),
    isOptional: boolean('is_optional').default(false).notNull(),
    ...timestamps,
  },
  (table) => [
    index('fee_heads_structure_idx').on(table.schoolId, table.feeStructureId),
  ],
);

export const feeConcessions = pgTable(
  'fee_concessions',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    schoolId: uuid('school_id').notNull().references(() => schools.id, { onDelete: 'cascade' }),
    name: text('name').notNull(),
    code: text('code').notNull(),
    type: concessionTypeEnum('type').default('flat').notNull(),
    value: integer('value').notNull(), // percentage or flat amount
    category: text('category').default('merit').notNull(), // 'merit', 'sibling', 'staff_ward', 'financial_aid', 'sports'
    isActive: boolean('is_active').default(true).notNull(),
    ...timestamps,
  },
  (table) => [
    unique().on(table.schoolId, table.code),
    index('fee_concessions_active_idx').on(table.schoolId, table.isActive),
  ],
);

export const studentFeeConcessions = pgTable(
  'student_fee_concessions',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    schoolId: uuid('school_id').notNull().references(() => schools.id, { onDelete: 'cascade' }),
    studentId: uuid('student_id').notNull().references(() => students.id, { onDelete: 'cascade' }),
    allocationId: uuid('allocation_id').notNull().references(() => studentFeeAllocations.id, { onDelete: 'cascade' }),
    concessionId: uuid('concession_id').notNull().references(() => feeConcessions.id, { onDelete: 'cascade' }),
    appliedAmount: integer('applied_amount').notNull(),
    reason: text('reason'),
    approvedByUserId: uuid('approved_by_user_id').references(() => appUsers.id, { onDelete: 'set null' }),
    ...timestamps,
  },
  (table) => [
    index('student_concessions_student_idx').on(table.schoolId, table.studentId),
    index('student_concessions_alloc_idx').on(table.schoolId, table.allocationId),
  ],
);

export const feeRefunds = pgTable(
  'fee_refunds',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    schoolId: uuid('school_id').notNull().references(() => schools.id, { onDelete: 'cascade' }),
    allocationId: uuid('allocation_id').notNull().references(() => studentFeeAllocations.id, { onDelete: 'cascade' }),
    studentId: uuid('student_id').notNull().references(() => students.id, { onDelete: 'cascade' }),
    paymentId: uuid('payment_id').references(() => feePayments.id, { onDelete: 'set null' }),
    refundNumber: text('refund_number').notNull(),
    amount: integer('amount').notNull(),
    reason: text('reason').notNull(),
    mode: text('mode').default('bank_transfer').notNull(), // 'bank_transfer', 'cash', 'cheque', 'gateway_refund'
    referenceNumber: text('reference_number'),
    status: feeRefundStatusEnum('status').default('pending').notNull(),
    approvedByUserId: uuid('approved_by_user_id').references(() => appUsers.id, { onDelete: 'set null' }),
    processedAt: timestamp('processed_at', { withTimezone: true }),
    ...timestamps,
  },
  (table) => [
    unique().on(table.schoolId, table.refundNumber),
    index('fee_refunds_alloc_idx').on(table.schoolId, table.allocationId),
    index('fee_refunds_student_idx').on(table.schoolId, table.studentId),
    index('fee_refunds_status_idx').on(table.schoolId, table.status),
  ],
);

export const studentLeaves = pgTable(
  'student_leaves',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    schoolId: uuid('school_id').notNull().references(() => schools.id, { onDelete: 'cascade' }),
    studentId: uuid('student_id').notNull().references(() => students.id, { onDelete: 'cascade' }),
    startDate: date('start_date').notNull(),
    endDate: date('end_date').notNull(),
    reason: text('reason').notNull(),
    documentUrl: text('document_url'),
    status: leaveStatusEnum('status').default('pending').notNull(),
    reviewedByStaffId: uuid('reviewed_by_staff_id').references(() => staff.id, { onDelete: 'set null' }),
    reviewerNotes: text('reviewer_notes'),
    reviewedAt: timestamp('reviewed_at', { withTimezone: true }),
    ...timestamps,
  },
  (table) => [
    index('student_leaves_student_idx').on(table.schoolId, table.studentId),
    index('student_leaves_status_idx').on(table.schoolId, table.status),
  ],
);

export const staffLeaves = pgTable(
  'staff_leaves',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    schoolId: uuid('school_id').notNull().references(() => schools.id, { onDelete: 'cascade' }),
    staffId: uuid('staff_id').notNull().references(() => staff.id, { onDelete: 'cascade' }),
    leaveType: leaveTypeEnum('leave_type').default('casual').notNull(),
    startDate: date('start_date').notNull(),
    endDate: date('end_date').notNull(),
    reason: text('reason').notNull(),
    status: leaveStatusEnum('status').default('pending').notNull(),
    reviewedByUserId: uuid('reviewed_by_user_id').references(() => appUsers.id, { onDelete: 'set null' }),
    reviewerNotes: text('reviewer_notes'),
    reviewedAt: timestamp('reviewed_at', { withTimezone: true }),
    ...timestamps,
  },
  (table) => [
    index('staff_leaves_staff_idx').on(table.schoolId, table.staffId),
    index('staff_leaves_status_idx').on(table.schoolId, table.status),
  ],
);

export const transportVehicles = pgTable(
  'transport_vehicles',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    schoolId: uuid('school_id').notNull().references(() => schools.id, { onDelete: 'cascade' }),
    vehicleNumber: text('vehicle_number').notNull(),
    model: text('model').notNull(),
    capacity: integer('capacity').notNull(),
    insuranceExpiry: date('insurance_expiry'),
    pollutionExpiry: date('pollution_expiry'),
    status: text('status').default('active').notNull(), // 'active', 'maintenance', 'retired'
    ...timestamps,
  },
  (table) => [
    unique().on(table.schoolId, table.vehicleNumber),
    index('transport_vehicles_status_idx').on(table.schoolId, table.status),
  ],
);

export const transportDrivers = pgTable(
  'transport_drivers',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    schoolId: uuid('school_id').notNull().references(() => schools.id, { onDelete: 'cascade' }),
    fullName: text('full_name').notNull(),
    phone: text('phone').notNull(),
    licenseNumber: text('license_number').notNull(),
    licenseExpiry: date('license_expiry'),
    status: text('status').default('active').notNull(), // 'active', 'on_leave', 'inactive'
    ...timestamps,
  },
  (table) => [
    unique().on(table.schoolId, table.licenseNumber),
    index('transport_drivers_status_idx').on(table.schoolId, table.status),
  ],
);

export const transportRoutes = pgTable(
  'transport_routes',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    schoolId: uuid('school_id').notNull().references(() => schools.id, { onDelete: 'cascade' }),
    routeNumber: text('route_number').notNull(),
    routeName: text('route_name').notNull(),
    startPoint: text('start_point').notNull(),
    endPoint: text('end_point').notNull(),
    vehicleId: uuid('vehicle_id').references(() => transportVehicles.id, { onDelete: 'set null' }),
    driverId: uuid('driver_id').references(() => transportDrivers.id, { onDelete: 'set null' }),
    status: text('status').default('active').notNull(), // 'active', 'inactive'
    ...timestamps,
  },
  (table) => [
    unique().on(table.schoolId, table.routeNumber),
    index('transport_routes_status_idx').on(table.schoolId, table.status),
  ],
);

export const transportStops = pgTable(
  'transport_stops',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    schoolId: uuid('school_id').notNull().references(() => schools.id, { onDelete: 'cascade' }),
    routeId: uuid('route_id').notNull().references(() => transportRoutes.id, { onDelete: 'cascade' }),
    stopName: text('stop_name').notNull(),
    pickupTime: text('pickup_time').notNull(),
    dropTime: text('drop_time').notNull(),
    stopOrder: integer('stop_order').default(1).notNull(),
    monthlyFeeAmount: integer('monthly_fee_amount').default(0).notNull(),
    latitude: text('latitude'),
    longitude: text('longitude'),
    ...timestamps,
  },
  (table) => [
    index('transport_stops_route_idx').on(table.schoolId, table.routeId, table.stopOrder),
  ],
);

export const studentTransportAllocations = pgTable(
  'student_transport_allocations',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    schoolId: uuid('school_id').notNull().references(() => schools.id, { onDelete: 'cascade' }),
    studentId: uuid('student_id').notNull().references(() => students.id, { onDelete: 'cascade' }),
    routeId: uuid('route_id').notNull().references(() => transportRoutes.id, { onDelete: 'cascade' }),
    stopId: uuid('stop_id').notNull().references(() => transportStops.id, { onDelete: 'cascade' }),
    academicYearId: uuid('academic_year_id').notNull().references(() => academicYears.id, { onDelete: 'cascade' }),
    status: text('status').default('active').notNull(), // 'active', 'inactive'
    startDate: date('start_date').notNull(),
    endDate: date('end_date'),
    ...timestamps,
  },
  (table) => [
    index('transport_alloc_student_idx').on(table.schoolId, table.studentId),
    index('transport_alloc_route_idx').on(table.schoolId, table.routeId),
  ],
);

export const transportLogs = pgTable(
  'transport_logs',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    schoolId: uuid('school_id').notNull().references(() => schools.id, { onDelete: 'cascade' }),
    routeId: uuid('route_id').notNull().references(() => transportRoutes.id, { onDelete: 'cascade' }),
    date: date('date').notNull(),
    tripType: text('trip_type').notNull(), // 'pickup', 'drop'
    status: text('status').default('scheduled').notNull(), // 'scheduled', 'in_transit', 'completed', 'delayed'
    currentStopId: uuid('current_stop_id').references(() => transportStops.id, { onDelete: 'set null' }),
    notes: text('notes'),
    ...timestamps,
  },
  (table) => [
    index('transport_logs_route_date_idx').on(table.schoolId, table.routeId, table.date),
  ],
);

export const issuedCertificates = pgTable(
  'issued_certificates',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    schoolId: uuid('school_id').notNull().references(() => schools.id, { onDelete: 'cascade' }),
    studentId: uuid('student_id').notNull().references(() => students.id, { onDelete: 'cascade' }),
    certificateType: certificateTypeEnum('certificate_type').notNull(),
    certificateNumber: text('certificate_number').notNull(),
    academicYearId: uuid('academic_year_id').references(() => academicYears.id, { onDelete: 'set null' }),
    issueDate: date('issue_date').notNull(),
    verificationCode: text('verification_code').notNull(),
    metadata: jsonb('metadata'),
    issuedByStaffId: uuid('issued_by_staff_id').references(() => staff.id, { onDelete: 'set null' }),
    status: certificateStatusEnum('status').default('valid').notNull(),
    ...timestamps,
  },
  (table) => [
    unique().on(table.schoolId, table.certificateNumber),
    unique().on(table.verificationCode),
    index('issued_cert_student_idx').on(table.schoolId, table.studentId),
    index('issued_cert_type_idx').on(table.schoolId, table.certificateType),
  ],
);

export const calendarEvents = pgTable(
  'calendar_events',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    schoolId: uuid('school_id').notNull().references(() => schools.id, { onDelete: 'cascade' }),
    academicYearId: uuid('academic_year_id').references(() => academicYears.id, { onDelete: 'set null' }),
    title: text('title').notNull(),
    description: text('description'),
    eventType: calendarEventTypeEnum('event_type').default('holiday').notNull(),
    startDate: date('start_date').notNull(),
    endDate: date('end_date').notNull(),
    isAllDay: boolean('is_all_day').default(true).notNull(),
    targetAudience: text('target_audience').default('all').notNull(), // 'all', 'teachers', 'students', 'parents'
    ...timestamps,
  },
  (table) => [
    index('calendar_events_date_idx').on(table.schoolId, table.startDate, table.endDate),
    index('calendar_events_type_idx').on(table.schoolId, table.eventType),
  ],
);

export const ptmSchedules = pgTable(
  'ptm_schedules',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    schoolId: uuid('school_id').notNull().references(() => schools.id, { onDelete: 'cascade' }),
    academicYearId: uuid('academic_year_id').references(() => academicYears.id, { onDelete: 'set null' }),
    title: text('title').notNull(),
    eventDate: date('event_date').notNull(),
    startTime: text('start_time').notNull(),
    endTime: text('end_time').notNull(),
    slotDurationMinutes: integer('slot_duration_minutes').default(15).notNull(),
    status: ptmStatusEnum('status').default('scheduled').notNull(),
    ...timestamps,
  },
  (table) => [
    index('ptm_schedules_date_idx').on(table.schoolId, table.eventDate),
  ],
);

export const ptmSlots = pgTable(
  'ptm_slots',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    schoolId: uuid('school_id').notNull().references(() => schools.id, { onDelete: 'cascade' }),
    scheduleId: uuid('schedule_id').notNull().references(() => ptmSchedules.id, { onDelete: 'cascade' }),
    teacherStaffId: uuid('teacher_staff_id').notNull().references(() => staff.id, { onDelete: 'cascade' }),
    startTime: text('start_time').notNull(),
    endTime: text('end_time').notNull(),
    status: ptmSlotStatusEnum('status').default('available').notNull(),
    bookedByStudentId: uuid('booked_by_student_id').references(() => students.id, { onDelete: 'set null' }),
    parentNotes: text('parent_notes'),
    teacherNotes: text('teacher_notes'),
    ...timestamps,
  },
  (table) => [
    index('ptm_slots_sched_teacher_idx').on(table.schoolId, table.scheduleId, table.teacherStaffId),
    index('ptm_slots_student_idx').on(table.schoolId, table.bookedByStudentId),
  ],
);

export const gradingSchemes = pgTable(
  'grading_schemes',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    schoolId: uuid('school_id').notNull().references(() => schools.id, { onDelete: 'cascade' }),
    academicYearId: uuid('academic_year_id').references(() => academicYears.id, { onDelete: 'set null' }),
    name: text('name').notNull(),
    board: gradingBoardEnum('board').default('cbse').notNull(),
    description: text('description'),
    isDefault: boolean('is_default').default(false).notNull(),
    passingPercentage: integer('passing_percentage').default(33).notNull(),
    config: text('config'), // JSON configuration for co-scholastic, terms, weights
    ...timestamps,
  },
  (table) => [
    index('grading_schemes_school_idx').on(table.schoolId, table.academicYearId),
  ],
);

export const gradingScales = pgTable(
  'grading_scales',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    schoolId: uuid('school_id').notNull().references(() => schools.id, { onDelete: 'cascade' }),
    schemeId: uuid('scheme_id').notNull().references(() => gradingSchemes.id, { onDelete: 'cascade' }),
    grade: text('grade').notNull(),
    minScore: integer('min_score').notNull(),
    maxScore: integer('max_score').notNull(),
    gradePoint: text('grade_point').notNull(),
    remarks: text('remarks'),
    orderIndex: integer('order_index').default(0).notNull(),
    ...timestamps,
  },
  (table) => [
    index('grading_scales_scheme_idx').on(table.schoolId, table.schemeId, table.orderIndex),
  ],
);

export const evaluationComponents = pgTable(
  'evaluation_components',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    schoolId: uuid('school_id').notNull().references(() => schools.id, { onDelete: 'cascade' }),
    schemeId: uuid('scheme_id').notNull().references(() => gradingSchemes.id, { onDelete: 'cascade' }),
    name: text('name').notNull(),
    componentType: assessmentComponentTypeEnum('component_type').notNull(),
    term: gradingTermEnum('term').default('annual').notNull(),
    weightagePercentage: integer('weightage_percentage').notNull(),
    maxMarks: integer('max_marks').notNull(),
    orderIndex: integer('order_index').default(0).notNull(),
    ...timestamps,
  },
  (table) => [
    index('eval_components_scheme_idx').on(table.schoolId, table.schemeId, table.term),
  ],
);

export const studentReportCards = pgTable(
  'student_report_cards',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    schoolId: uuid('school_id').notNull().references(() => schools.id, { onDelete: 'cascade' }),
    academicYearId: uuid('academic_year_id').notNull().references(() => academicYears.id, { onDelete: 'cascade' }),
    classId: uuid('class_id').notNull().references(() => classes.id, { onDelete: 'cascade' }),
    sectionId: uuid('section_id').notNull().references(() => sections.id, { onDelete: 'cascade' }),
    studentId: uuid('student_id').notNull().references(() => students.id, { onDelete: 'cascade' }),
    schemeId: uuid('scheme_id').notNull().references(() => gradingSchemes.id, { onDelete: 'cascade' }),
    term: gradingTermEnum('term').default('annual').notNull(),
    totalMaxMarks: integer('total_max_marks').notNull(),
    totalObtainedMarks: integer('total_obtained_marks').notNull(),
    overallPercentage: text('overall_percentage').notNull(),
    overallGrade: text('overall_grade').notNull(),
    overallGradePoint: text('overall_grade_point'),
    attendancePercentage: text('attendance_percentage'),
    scholasticData: text('scholastic_data').notNull(), // JSON string
    coScholasticData: text('co_scholastic_data'), // JSON string
    teacherRemarks: text('teacher_remarks'),
    principalRemarks: text('principal_remarks'),
    resultStatus: reportCardResultStatusEnum('result_status').default('promoted').notNull(),
    isPublished: boolean('is_published').default(false).notNull(),
    publishedAt: timestamp('published_at', { withTimezone: true }),
    ...timestamps,
  },
  (table) => [
    unique().on(table.schoolId, table.academicYearId, table.studentId, table.term),
    index('report_cards_section_idx').on(table.schoolId, table.sectionId, table.term),
    index('report_cards_student_idx').on(table.schoolId, table.studentId),
  ],
);

export const offlineAttendanceSyncLogs = pgTable(
  'offline_attendance_sync_logs',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    schoolId: uuid('school_id').notNull().references(() => schools.id, { onDelete: 'cascade' }),
    staffId: uuid('staff_id').notNull().references(() => staff.id, { onDelete: 'cascade' }),
    clientSyncBatchId: text('client_sync_batch_id').notNull(),
    payloadRecordsCount: integer('payload_records_count').notNull(),
    syncedCount: integer('synced_count').notNull(),
    conflictCount: integer('conflict_count').default(0).notNull(),
    status: offlineSyncStatusEnum('status').default('success').notNull(),
    details: text('details'),
    syncedAt: timestamp('synced_at', { withTimezone: true }).defaultNow().notNull(),
    ...timestamps,
  },
  (table) => [
    index('offline_sync_school_staff_idx').on(table.schoolId, table.staffId, table.syncedAt),
    index('offline_sync_batch_idx').on(table.schoolId, table.clientSyncBatchId),
  ],
);



