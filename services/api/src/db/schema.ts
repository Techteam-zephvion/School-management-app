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
  uuid,
} from 'drizzle-orm/pg-core';

export const roleEnum = pgEnum('role', ['admin', 'teacher']);
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
    admissionNumber: text('admission_number').notNull(),
    fullName: text('full_name').notNull(),
    guardianName: text('guardian_name'),
    guardianPhone: text('guardian_phone'),
    isActive: boolean('is_active').default(true).notNull(),
    ...timestamps,
  },
  (table) => [unique().on(table.schoolId, table.admissionNumber)],
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
