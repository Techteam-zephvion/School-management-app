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
  guardianName: z.string().optional(),
  guardianPhone: z.string().optional(),
  academicYearId: z.uuid(),
  classId: z.uuid(),
  sectionId: z.uuid(),
  rollNumber: z.string().optional(),
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
  roles: z.array(z.enum(['admin', 'teacher'])).min(1),
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
