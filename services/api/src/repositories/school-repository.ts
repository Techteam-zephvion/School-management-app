import { and, desc, eq, gte, lte, ne } from 'drizzle-orm';
import type { Db } from '../db/client';
import {
  academicYears,
  appUsers,
  attendanceRecords,
  attendanceSessions,
  classes,
  schools,
  sections,
  staff,
  studentEnrollments,
  students,
  subjects,
  timetableEntries,
  teacherAssignments,
  userRoles,
} from '../db/schema';
import { ApiError } from '../http/errors';
import type { AuthUser } from '../types';
import type {
  createAcademicYearSchema,
  createClassSchema,
  createSchoolSchema,
  createSectionSchema,
  createStaffSchema,
  createStudentSchema,
  createSubjectSchema,
  createTeacherAssignmentSchema,
  createTimetableEntrySchema,
  createUserSchema,
  saveAttendanceSchema,
  timetableQuerySchema,
  updateTimetableEntrySchema,
} from '../http/validation';
import type { z } from 'zod';

export type SchoolRepository = ReturnType<typeof createSchoolRepository>;

type TimetableFilters = z.infer<typeof timetableQuerySchema>;
type TimetableInput = z.infer<typeof createTimetableEntrySchema>;
type TimetableUpdateInput = z.infer<typeof updateTimetableEntrySchema>;

export function createSchoolRepository(db: Db) {
  return {
    async overview(user: AuthUser) {
      const [school] = await db.select().from(schools).where(eq(schools.id, user.schoolId)).limit(1);
      const [year] = await db
        .select()
        .from(academicYears)
        .where(and(eq(academicYears.schoolId, user.schoolId), eq(academicYears.isActive, true)))
        .limit(1);

      return { school, activeAcademicYear: year ?? null, roles: user.roles };
    },

    async createSchool(input: z.infer<typeof createSchoolSchema>) {
      const [created] = await db.insert(schools).values(input).returning();
      return created;
    },

    async createUser(user: AuthUser, input: z.infer<typeof createUserSchema>) {
      const [created] = await db
        .insert(appUsers)
        .values({
          schoolId: user.schoolId,
          neonUserId: input.neonUserId,
          email: input.email,
          displayName: input.displayName,
        })
        .returning();
      if (!created) throw new ApiError(500, 'Unable to create user');

      await db.insert(userRoles).values(input.roles.map((role) => ({ userId: created.id, role })));
      return { ...created, roles: input.roles };
    },

    async listAcademicYears(user: AuthUser) {
      return db
        .select()
        .from(academicYears)
        .where(eq(academicYears.schoolId, user.schoolId))
        .orderBy(desc(academicYears.startsOn))
        .limit(100);
    },

    async createAcademicYear(user: AuthUser, input: z.infer<typeof createAcademicYearSchema>) {
      const [created] = await db.insert(academicYears).values({ ...input, schoolId: user.schoolId }).returning();
      return created;
    },

    async listClasses(user: AuthUser) {
      return db
        .select()
        .from(classes)
        .where(eq(classes.schoolId, user.schoolId))
        .orderBy(classes.sortOrder)
        .limit(200);
    },

    async createClass(user: AuthUser, input: z.infer<typeof createClassSchema>) {
      const [created] = await db.insert(classes).values({ ...input, schoolId: user.schoolId }).returning();
      return created;
    },

    async listSections(user: AuthUser) {
      return db
        .select()
        .from(sections)
        .where(eq(sections.schoolId, user.schoolId))
        .limit(300);
    },

    async createSection(user: AuthUser, input: z.infer<typeof createSectionSchema>) {
      const [created] = await db.insert(sections).values({ ...input, schoolId: user.schoolId }).returning();
      return created;
    },

    async listSubjects(user: AuthUser) {
      return db
        .select()
        .from(subjects)
        .where(eq(subjects.schoolId, user.schoolId))
        .limit(200);
    },

    async createSubject(user: AuthUser, input: z.infer<typeof createSubjectSchema>) {
      const [created] = await db.insert(subjects).values({ ...input, schoolId: user.schoolId }).returning();
      return created;
    },

    async listStaff(user: AuthUser) {
      return db
        .select()
        .from(staff)
        .where(eq(staff.schoolId, user.schoolId))
        .limit(300);
    },

    async createStaff(user: AuthUser, input: z.infer<typeof createStaffSchema>) {
      const [created] = await db.insert(staff).values({ ...input, schoolId: user.schoolId }).returning();
      return created;
    },

    async listStudents(user: AuthUser) {
      return db
        .select({
          id: students.id,
          admissionNumber: students.admissionNumber,
          fullName: students.fullName,
          guardianName: students.guardianName,
          guardianPhone: students.guardianPhone,
          classId: studentEnrollments.classId,
          sectionId: studentEnrollments.sectionId,
          academicYearId: studentEnrollments.academicYearId,
          rollNumber: studentEnrollments.rollNumber,
        })
        .from(students)
        .leftJoin(studentEnrollments, eq(studentEnrollments.studentId, students.id))
        .where(eq(students.schoolId, user.schoolId))
        .limit(500);
    },

    async createStudent(user: AuthUser, input: z.infer<typeof createStudentSchema>) {
      const [created] = await db
        .insert(students)
        .values({
          schoolId: user.schoolId,
          admissionNumber: input.admissionNumber,
          fullName: input.fullName,
          guardianName: input.guardianName,
          guardianPhone: input.guardianPhone,
        })
        .returning();
      if (!created) throw new ApiError(500, 'Unable to create student');

      await db.insert(studentEnrollments).values({
        schoolId: user.schoolId,
        studentId: created.id,
        academicYearId: input.academicYearId,
        classId: input.classId,
        sectionId: input.sectionId,
        rollNumber: input.rollNumber,
      });

      return created;
    },

    async listTeacherAssignments(user: AuthUser) {
      return db
        .select()
        .from(teacherAssignments)
        .where(eq(teacherAssignments.schoolId, user.schoolId))
        .limit(500);
    },

    async createTeacherAssignment(user: AuthUser, input: z.infer<typeof createTeacherAssignmentSchema>) {
      const [created] = await db
        .insert(teacherAssignments)
        .values({
          ...input,
          schoolId: user.schoolId,
          subjectId: input.subjectId ?? null,
        })
        .returning();
      return created;
    },

    async listTimetableEntries(user: AuthUser, filters: TimetableFilters = {}) {
      const conditions = [eq(timetableEntries.schoolId, user.schoolId)];
      if (filters.academicYearId) conditions.push(eq(timetableEntries.academicYearId, filters.academicYearId));
      if (filters.classId) conditions.push(eq(timetableEntries.classId, filters.classId));
      if (filters.sectionId) conditions.push(eq(timetableEntries.sectionId, filters.sectionId));
      if (filters.staffId) conditions.push(eq(timetableEntries.staffId, filters.staffId));
      if (filters.subjectId) conditions.push(eq(timetableEntries.subjectId, filters.subjectId));
      if (filters.dayOfWeek) conditions.push(eq(timetableEntries.dayOfWeek, filters.dayOfWeek));

      const rows = await db
        .select({
          entry: timetableEntries,
          className: classes.name,
          sectionName: sections.name,
          subjectName: subjects.name,
          staffName: staff.fullName,
          academicYearName: academicYears.name,
        })
        .from(timetableEntries)
        .innerJoin(classes, eq(timetableEntries.classId, classes.id))
        .innerJoin(sections, eq(timetableEntries.sectionId, sections.id))
        .innerJoin(subjects, eq(timetableEntries.subjectId, subjects.id))
        .innerJoin(staff, eq(timetableEntries.staffId, staff.id))
        .innerJoin(academicYears, eq(timetableEntries.academicYearId, academicYears.id))
        .where(and(...conditions))
        .orderBy(timetableEntries.dayOfWeek, timetableEntries.startTime)
        .limit(500);

      return rows.map((r) => ({
        ...r.entry,
        className: r.className,
        sectionName: r.sectionName,
        subjectName: r.subjectName,
        staffName: r.staffName,
        academicYearName: r.academicYearName,
      }));
    },

    async createTimetableEntry(user: AuthUser, input: TimetableInput) {
      await assertTimetableInputIsValid(db, user, input);
      await assertNoTimetableConflict(db, user, input);

      const [created] = await db
        .insert(timetableEntries)
        .values({
          ...input,
          schoolId: user.schoolId,
          periodNumber: input.periodNumber ?? null,
          label: input.label ?? null,
        })
        .returning();

      return created;
    },

    async updateTimetableEntry(user: AuthUser, id: string, input: TimetableUpdateInput) {
      const [existing] = await db
        .select()
        .from(timetableEntries)
        .where(and(eq(timetableEntries.schoolId, user.schoolId), eq(timetableEntries.id, id)))
        .limit(1);

      if (!existing) throw new ApiError(404, 'Timetable entry not found');

      const next: TimetableInput = {
        academicYearId: input.academicYearId ?? existing.academicYearId,
        classId: input.classId ?? existing.classId,
        sectionId: input.sectionId ?? existing.sectionId,
        subjectId: input.subjectId ?? existing.subjectId,
        staffId: input.staffId ?? existing.staffId,
        dayOfWeek: input.dayOfWeek ?? existing.dayOfWeek,
        startTime: input.startTime ?? existing.startTime,
        endTime: input.endTime ?? existing.endTime,
        periodNumber: input.periodNumber === undefined ? existing.periodNumber : input.periodNumber,
        label: input.label === undefined ? existing.label : input.label,
      };

      if (next.endTime <= next.startTime) {
        throw new ApiError(422, 'End time must be later than start time');
      }

      await assertTimetableInputIsValid(db, user, next);
      await assertNoTimetableConflict(db, user, next, id);

      const [updated] = await db
        .update(timetableEntries)
        .set({
          academicYearId: next.academicYearId,
          classId: next.classId,
          sectionId: next.sectionId,
          subjectId: next.subjectId,
          staffId: next.staffId,
          dayOfWeek: next.dayOfWeek,
          startTime: next.startTime,
          endTime: next.endTime,
          periodNumber: next.periodNumber ?? null,
          label: next.label ?? null,
          updatedAt: new Date(),
        })
        .where(and(eq(timetableEntries.schoolId, user.schoolId), eq(timetableEntries.id, id)))
        .returning();

      return updated;
    },

    async deleteTimetableEntry(user: AuthUser, id: string) {
      const [deleted] = await db
        .delete(timetableEntries)
        .where(and(eq(timetableEntries.schoolId, user.schoolId), eq(timetableEntries.id, id)))
        .returning({ id: timetableEntries.id });

      if (!deleted) throw new ApiError(404, 'Timetable entry not found');
      return deleted;
    },

    async teacherAssignmentsFor(user: AuthUser) {
      if (!user.staffId) return [];
      const rows = await db
        .select({
          assignment: teacherAssignments,
          className: classes.name,
          sectionName: sections.name,
        })
        .from(teacherAssignments)
        .innerJoin(classes, eq(teacherAssignments.classId, classes.id))
        .innerJoin(sections, eq(teacherAssignments.sectionId, sections.id))
        .where(and(eq(teacherAssignments.schoolId, user.schoolId), eq(teacherAssignments.staffId, user.staffId)))
        .limit(100);

      return rows.map((r) => ({
        ...r.assignment,
        className: r.className,
        sectionName: r.sectionName,
      }));
    },

    async teacherTimetable(user: AuthUser, filters: TimetableFilters = {}) {
      if (!user.staffId) return [];
      return this.listTimetableEntries(user, {
        ...filters,
        staffId: user.staffId,
      });
    },

    async rosterForSection(user: AuthUser, sectionId: string, academicYearId: string) {
      const isAdmin = user.roles.includes('admin');
      if (!isAdmin) {
        if (!user.staffId) {
          throw new ApiError(403, 'Only assigned teachers can access class rosters');
        }
        const [assigned] = await db
          .select({ id: teacherAssignments.id })
          .from(teacherAssignments)
          .where(
            and(
              eq(teacherAssignments.schoolId, user.schoolId),
              eq(teacherAssignments.staffId, user.staffId),
              eq(teacherAssignments.sectionId, sectionId),
              eq(teacherAssignments.academicYearId, academicYearId),
            ),
          )
          .limit(1);

        if (!assigned) {
          throw new ApiError(403, 'Teacher is not assigned to this class section');
        }
      }

      return db
        .select({
          id: students.id,
          admissionNumber: students.admissionNumber,
          fullName: students.fullName,
          rollNumber: studentEnrollments.rollNumber,
        })
        .from(studentEnrollments)
        .innerJoin(students, eq(students.id, studentEnrollments.studentId))
        .where(
          and(
            eq(studentEnrollments.schoolId, user.schoolId),
            eq(studentEnrollments.sectionId, sectionId),
            eq(studentEnrollments.academicYearId, academicYearId),
          ),
        )
        .orderBy(studentEnrollments.rollNumber, students.fullName)
        .limit(200);
    },

    async saveAttendance(user: AuthUser, input: z.infer<typeof saveAttendanceSchema>) {
      await assertTeacherCanTakeAttendance(db, user, input);

      const enrolledRows = await db
        .select({ studentId: studentEnrollments.studentId })
        .from(studentEnrollments)
        .where(
          and(
            eq(studentEnrollments.schoolId, user.schoolId),
            eq(studentEnrollments.sectionId, input.sectionId),
            eq(studentEnrollments.academicYearId, input.academicYearId),
          ),
        );

      const enrolledSet = new Set(enrolledRows.map((r) => r.studentId));
      for (const record of input.records) {
        if (!enrolledSet.has(record.studentId)) {
          throw new ApiError(400, `Student ${record.studentId} is not enrolled in this section`);
        }
      }

      const [session] = await db
        .insert(attendanceSessions)
        .values({
          schoolId: user.schoolId,
          academicYearId: input.academicYearId,
          classId: input.classId,
          sectionId: input.sectionId,
          subjectId: input.subjectId ?? null,
          kind: input.kind,
          attendanceDate: input.attendanceDate,
          periodNumber: input.periodNumber ?? null,
          notes: input.notes,
          takenByStaffId: user.staffId!,
        })
        .onConflictDoUpdate({
          target: [
            attendanceSessions.schoolId,
            attendanceSessions.academicYearId,
            attendanceSessions.sectionId,
            attendanceSessions.kind,
            attendanceSessions.attendanceDate,
            attendanceSessions.periodNumber,
            attendanceSessions.subjectId,
          ],
          set: {
            notes: input.notes,
            takenByStaffId: user.staffId!,
            updatedAt: new Date(),
          },
        })
        .returning();

      if (!session) throw new ApiError(500, 'Unable to save attendance session');

      for (const record of input.records) {
        await db
          .insert(attendanceRecords)
          .values({
            schoolId: user.schoolId,
            sessionId: session.id,
            studentId: record.studentId,
            status: record.status,
            remarks: record.remarks,
          })
          .onConflictDoUpdate({
            target: [attendanceRecords.sessionId, attendanceRecords.studentId],
            set: {
              status: record.status,
              remarks: record.remarks,
              updatedAt: new Date(),
            },
          });
      }

      return { sessionId: session.id, savedRecords: input.records.length };
    },

    async attendanceSummary(
      user: AuthUser,
      filters?: {
        startDate?: string | undefined;
        endDate?: string | undefined;
        classId?: string | undefined;
        sectionId?: string | undefined;
      },
    ) {
      const conditions = [eq(attendanceSessions.schoolId, user.schoolId)];

      // Teachers are scoped to their own sessions unless they have the admin role
      if (!user.roles.includes('admin') && user.staffId) {
        conditions.push(eq(attendanceSessions.takenByStaffId, user.staffId));
      }

      if (filters?.startDate) {
        conditions.push(gte(attendanceSessions.attendanceDate, filters.startDate));
      }
      if (filters?.endDate) {
        conditions.push(lte(attendanceSessions.attendanceDate, filters.endDate));
      }
      if (filters?.classId) {
        conditions.push(eq(attendanceSessions.classId, filters.classId));
      }
      if (filters?.sectionId) {
        conditions.push(eq(attendanceSessions.sectionId, filters.sectionId));
      }

      const rows = await db
        .select({
          session: attendanceSessions,
          className: classes.name,
          sectionName: sections.name,
          staffName: staff.fullName,
        })
        .from(attendanceSessions)
        .innerJoin(classes, eq(attendanceSessions.classId, classes.id))
        .innerJoin(sections, eq(attendanceSessions.sectionId, sections.id))
        .innerJoin(staff, eq(attendanceSessions.takenByStaffId, staff.id))
        .where(and(...conditions))
        .orderBy(desc(attendanceSessions.attendanceDate))
        .limit(500);

      return {
        sessions: rows.map((r) => ({
          ...r.session,
          className: r.className,
          sectionName: r.sectionName,
          staffName: r.staffName,
        })),
      };
    },

    async studentAttendanceSummary(user: AuthUser, studentId: string) {
      const [student] = await db
        .select()
        .from(students)
        .where(and(eq(students.schoolId, user.schoolId), eq(students.id, studentId)))
        .limit(1);

      if (!student) throw new ApiError(404, 'Student not found');

      const rows = await db
        .select({
          record: attendanceRecords,
          session: attendanceSessions,
          className: classes.name,
          sectionName: sections.name,
        })
        .from(attendanceRecords)
        .innerJoin(attendanceSessions, eq(attendanceRecords.sessionId, attendanceSessions.id))
        .innerJoin(classes, eq(attendanceSessions.classId, classes.id))
        .innerJoin(sections, eq(attendanceSessions.sectionId, sections.id))
        .where(
          and(
            eq(attendanceRecords.schoolId, user.schoolId),
            eq(attendanceRecords.studentId, studentId),
          ),
        )
        .orderBy(desc(attendanceSessions.attendanceDate))
        .limit(500);

      const total = rows.length;
      let present = 0;
      let absent = 0;
      let late = 0;
      let excused = 0;

      for (const r of rows) {
        if (r.record.status === 'present') present++;
        else if (r.record.status === 'absent') absent++;
        else if (r.record.status === 'late') late++;
        else if (r.record.status === 'excused') excused++;
      }

      const attendanceRate = total > 0 ? Math.round(((present + late) / total) * 100) : 100;

      return {
        student,
        stats: {
          totalSessions: total,
          present,
          absent,
          late,
          excused,
          attendanceRate,
        },
        records: rows.map((r) => ({
          date: r.session.attendanceDate,
          kind: r.session.kind,
          periodNumber: r.session.periodNumber,
          status: r.record.status,
          className: r.className,
          sectionName: r.sectionName,
        })),
      };
    },
  };
}

async function assertTeacherCanTakeAttendance(
  db: Db,
  user: AuthUser,
  input: z.infer<typeof saveAttendanceSchema>,
) {
  const canAdminTakeAttendance = user.roles.includes('admin');
  if (canAdminTakeAttendance) return;

  if (!user.staffId || !user.roles.includes('teacher')) {
    throw new ApiError(403, 'Only assigned teachers can take attendance');
  }

  const predicates = [
    eq(teacherAssignments.schoolId, user.schoolId),
    eq(teacherAssignments.staffId, user.staffId),
    eq(teacherAssignments.academicYearId, input.academicYearId),
    eq(teacherAssignments.sectionId, input.sectionId),
  ];

  if (input.kind === 'daily') {
    predicates.push(eq(teacherAssignments.canTakeDailyAttendance, true));
  } else if (input.subjectId) {
    predicates.push(eq(teacherAssignments.subjectId, input.subjectId));
  }

  const [assignment] = await db.select().from(teacherAssignments).where(and(...predicates)).limit(1);
  if (!assignment) {
    throw new ApiError(403, 'Teacher is not assigned to this attendance session');
  }
}

async function assertTimetableInputIsValid(db: Db, user: AuthUser, input: TimetableInput) {
  const [section] = await db
    .select({ id: sections.id, classId: sections.classId })
    .from(sections)
    .where(and(eq(sections.schoolId, user.schoolId), eq(sections.id, input.sectionId), eq(sections.classId, input.classId)))
    .limit(1);
  if (!section) throw new ApiError(422, 'Selected section does not belong to the selected class');

  const [year] = await db
    .select({ id: academicYears.id })
    .from(academicYears)
    .where(and(eq(academicYears.schoolId, user.schoolId), eq(academicYears.id, input.academicYearId)))
    .limit(1);
  if (!year) throw new ApiError(422, 'Selected academic year is not available');

  const [subject] = await db
    .select({ id: subjects.id })
    .from(subjects)
    .where(and(eq(subjects.schoolId, user.schoolId), eq(subjects.id, input.subjectId)))
    .limit(1);
  if (!subject) throw new ApiError(422, 'Selected subject is not available');

  const [teacher] = await db
    .select({ id: staff.id })
    .from(staff)
    .where(and(eq(staff.schoolId, user.schoolId), eq(staff.id, input.staffId), eq(staff.isTeacher, true)))
    .limit(1);
  if (!teacher) throw new ApiError(422, 'Selected teacher is not available');

  const [assignment] = await db
    .select({ id: teacherAssignments.id })
    .from(teacherAssignments)
    .where(
      and(
        eq(teacherAssignments.schoolId, user.schoolId),
        eq(teacherAssignments.staffId, input.staffId),
        eq(teacherAssignments.academicYearId, input.academicYearId),
        eq(teacherAssignments.classId, input.classId),
        eq(teacherAssignments.sectionId, input.sectionId),
        eq(teacherAssignments.subjectId, input.subjectId),
      ),
    )
    .limit(1);

  if (!assignment) {
    throw new ApiError(422, 'Selected teacher is not assigned to teach this subject and section');
  }
}

async function assertNoTimetableConflict(
  db: Db,
  user: AuthUser,
  input: TimetableInput,
  excludeId?: string,
) {
  const teacherConditions = [
    eq(timetableEntries.schoolId, user.schoolId),
    eq(timetableEntries.academicYearId, input.academicYearId),
    eq(timetableEntries.staffId, input.staffId),
    eq(timetableEntries.dayOfWeek, input.dayOfWeek),
    lte(timetableEntries.startTime, input.endTime),
    gte(timetableEntries.endTime, input.startTime),
  ];
  const sectionConditions = [
    eq(timetableEntries.schoolId, user.schoolId),
    eq(timetableEntries.academicYearId, input.academicYearId),
    eq(timetableEntries.sectionId, input.sectionId),
    eq(timetableEntries.dayOfWeek, input.dayOfWeek),
    lte(timetableEntries.startTime, input.endTime),
    gte(timetableEntries.endTime, input.startTime),
  ];

  if (excludeId) {
    teacherConditions.push(ne(timetableEntries.id, excludeId));
    sectionConditions.push(ne(timetableEntries.id, excludeId));
  }

  const teacherRows = await db
    .select({ id: timetableEntries.id, startTime: timetableEntries.startTime, endTime: timetableEntries.endTime })
    .from(timetableEntries)
    .where(and(...teacherConditions))
    .limit(20);

  const teacherConflict = teacherRows.find((row) => overlaps(input.startTime, input.endTime, row.startTime, row.endTime));
  if (teacherConflict) {
    throw new ApiError(409, `Teacher has an overlapping lesson from ${teacherConflict.startTime} to ${teacherConflict.endTime}`);
  }

  const sectionRows = await db
    .select({ id: timetableEntries.id, startTime: timetableEntries.startTime, endTime: timetableEntries.endTime })
    .from(timetableEntries)
    .where(and(...sectionConditions))
    .limit(20);

  const sectionConflict = sectionRows.find((row) => overlaps(input.startTime, input.endTime, row.startTime, row.endTime));
  if (sectionConflict) {
    throw new ApiError(409, `Class section has an overlapping lesson from ${sectionConflict.startTime} to ${sectionConflict.endTime}`);
  }
}

function overlaps(startA: string, endA: string, startB: string, endB: string) {
  return toMinutes(startA) < toMinutes(endB) && toMinutes(startB) < toMinutes(endA);
}

function toMinutes(value: string) {
  const [hour, minute] = value.split(':').map(Number);
  return (hour ?? 0) * 60 + (minute ?? 0);
}
