import { and, eq } from 'drizzle-orm';
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
  teacherAssignments,
  userRoles,
} from '../db/schema';
import { ApiError } from '../http/errors';
import type { AuthUser, Role } from '../types';
import type {
  createAcademicYearSchema,
  createClassSchema,
  createSchoolSchema,
  createSectionSchema,
  createStaffSchema,
  createStudentSchema,
  createSubjectSchema,
  createTeacherAssignmentSchema,
  createUserSchema,
  saveAttendanceSchema,
} from '../http/validation';
import type { z } from 'zod';

export type SchoolRepository = ReturnType<typeof createSchoolRepository>;

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
      return db.select().from(academicYears).where(eq(academicYears.schoolId, user.schoolId));
    },

    async createAcademicYear(user: AuthUser, input: z.infer<typeof createAcademicYearSchema>) {
      const [created] = await db.insert(academicYears).values({ ...input, schoolId: user.schoolId }).returning();
      return created;
    },

    async listClasses(user: AuthUser) {
      return db.select().from(classes).where(eq(classes.schoolId, user.schoolId));
    },

    async createClass(user: AuthUser, input: z.infer<typeof createClassSchema>) {
      const [created] = await db.insert(classes).values({ ...input, schoolId: user.schoolId }).returning();
      return created;
    },

    async listSections(user: AuthUser) {
      return db.select().from(sections).where(eq(sections.schoolId, user.schoolId));
    },

    async createSection(user: AuthUser, input: z.infer<typeof createSectionSchema>) {
      const [created] = await db.insert(sections).values({ ...input, schoolId: user.schoolId }).returning();
      return created;
    },

    async listSubjects(user: AuthUser) {
      return db.select().from(subjects).where(eq(subjects.schoolId, user.schoolId));
    },

    async createSubject(user: AuthUser, input: z.infer<typeof createSubjectSchema>) {
      const [created] = await db.insert(subjects).values({ ...input, schoolId: user.schoolId }).returning();
      return created;
    },

    async listStaff(user: AuthUser) {
      return db.select().from(staff).where(eq(staff.schoolId, user.schoolId));
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
        .where(eq(students.schoolId, user.schoolId));
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
      return db.select().from(teacherAssignments).where(eq(teacherAssignments.schoolId, user.schoolId));
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

    async teacherAssignmentsFor(user: AuthUser) {
      if (!user.staffId) return [];
      return db
        .select()
        .from(teacherAssignments)
        .where(and(eq(teacherAssignments.schoolId, user.schoolId), eq(teacherAssignments.staffId, user.staffId)));
    },

    async rosterForSection(user: AuthUser, sectionId: string, academicYearId: string) {
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
        );
    },

    async saveAttendance(user: AuthUser, input: z.infer<typeof saveAttendanceSchema>) {
      await assertTeacherCanTakeAttendance(db, user, input);

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

    async attendanceSummary(user: AuthUser) {
      const sessions = await db
        .select()
        .from(attendanceSessions)
        .where(eq(attendanceSessions.schoolId, user.schoolId));
      return { sessions };
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
