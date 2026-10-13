import { and, desc, eq, gte, lte, ne } from 'drizzle-orm';
import type { Db } from '../db/client';
import {
  academicYears,
  aiUsageEvents,
  announcements,
  appUsers,
  attendanceRecords,
  attendanceSessions,
  classes,
  homeworkAssignments,
  schools,
  sections,
  staff,
  studentEnrollments,
  studentGuardians,
  students,
  subjects,
  teacherMaterials,
  timetableEntries,
  teacherAssignments,
  userRoles,
} from '../db/schema';
import { ApiError } from '../http/errors';
import type { AuthUser } from '../types';
import type {
  createAcademicYearSchema,
  createAnnouncementSchema,
  createHomeworkAssignmentSchema,
  createClassSchema,
  createSchoolSchema,
  createSectionSchema,
  createStaffSchema,
  createStudentSchema,
  createStudentGuardianLinkSchema,
  createSubjectSchema,
  createTeacherAssignmentSchema,
  createTeacherMaterialSchema,
  createTimetableEntrySchema,
  createUserSchema,
  saveAttendanceSchema,
  timetableQuerySchema,
  updateTeacherMaterialSchema,
  updateHomeworkAssignmentSchema,
  updateTimetableEntrySchema,
} from '../http/validation';
import type { z } from 'zod';

export type SchoolRepository = ReturnType<typeof createSchoolRepository>;

type TimetableFilters = z.infer<typeof timetableQuerySchema>;
type TimetableInput = z.infer<typeof createTimetableEntrySchema>;
type TimetableUpdateInput = z.infer<typeof updateTimetableEntrySchema>;
type TeacherMaterialInput = z.infer<typeof createTeacherMaterialSchema>;
type TeacherMaterialUpdateInput = z.infer<typeof updateTeacherMaterialSchema>;
type AnnouncementInput = z.infer<typeof createAnnouncementSchema>;
type HomeworkAssignmentInput = z.infer<typeof createHomeworkAssignmentSchema>;
type HomeworkAssignmentUpdateInput = z.infer<typeof updateHomeworkAssignmentSchema>;

export function createSchoolRepository(db: Db) {
  return {
    async recordAiUsage(
      user: AuthUser,
      input: {
        feature: string;
        generationType?: string | null | undefined;
        status: 'success' | 'failure' | 'limited';
        latencyMs?: number | null | undefined;
        inputTokens?: number | null | undefined;
        outputTokens?: number | null | undefined;
        totalTokens?: number | null | undefined;
        model?: string | null | undefined;
        errorCategory?: string | null | undefined;
      },
    ) {
      const [created] = await db
        .insert(aiUsageEvents)
        .values({
          schoolId: user.schoolId,
          appUserId: user.appUserId,
          staffId: user.staffId ?? null,
          feature: input.feature,
          generationType: input.generationType ?? null,
          status: input.status,
          latencyMs: input.latencyMs ?? null,
          inputTokens: input.inputTokens ?? null,
          outputTokens: input.outputTokens ?? null,
          totalTokens: input.totalTokens ?? null,
          model: input.model ?? null,
          errorCategory: input.errorCategory ?? null,
        })
        .returning({ id: aiUsageEvents.id });
      return created;
    },

    async countAiUsageSince(user: AuthUser, since: Date) {
      const rows = await db
        .select({ id: aiUsageEvents.id })
        .from(aiUsageEvents)
        .where(
          and(
            eq(aiUsageEvents.schoolId, user.schoolId),
            eq(aiUsageEvents.appUserId, user.appUserId),
            gte(aiUsageEvents.createdAt, since),
          ),
        )
        .limit(10000);
      return rows.length;
    },

    async aiUsageSummary(
      user: AuthUser,
      filters: {
        startDate?: string | undefined;
        endDate?: string | undefined;
      },
    ) {
      const conditions = [eq(aiUsageEvents.schoolId, user.schoolId)];
      if (filters.startDate) conditions.push(gte(aiUsageEvents.createdAt, new Date(`${filters.startDate}T00:00:00.000Z`)));
      if (filters.endDate) conditions.push(lte(aiUsageEvents.createdAt, new Date(`${filters.endDate}T23:59:59.999Z`)));

      const rows = await db
        .select()
        .from(aiUsageEvents)
        .where(and(...conditions))
        .orderBy(desc(aiUsageEvents.createdAt))
        .limit(5000);

      return summarizeAiUsage(rows);
    },

    async listAdminAnnouncements(user: AuthUser) {
      const rows = await db
        .select({
          announcement: announcements,
          className: classes.name,
          sectionName: sections.name,
          authorName: appUsers.displayName,
        })
        .from(announcements)
        .innerJoin(appUsers, eq(announcements.authorUserId, appUsers.id))
        .leftJoin(classes, eq(announcements.classId, classes.id))
        .leftJoin(sections, eq(announcements.sectionId, sections.id))
        .where(eq(announcements.schoolId, user.schoolId))
        .orderBy(desc(announcements.publishedAt))
        .limit(200);

      return rows.map(announcementWithLabels);
    },

    async createAdminAnnouncement(user: AuthUser, input: AnnouncementInput) {
      await assertAnnouncementTarget(db, user, input);

      const [created] = await db
        .insert(announcements)
        .values({
          schoolId: user.schoolId,
          authorUserId: user.appUserId,
          authorStaffId: user.staffId ?? null,
          audience: input.audience,
          priority: input.priority,
          classId: input.audience === 'class_section' ? input.classId! : null,
          sectionId: input.audience === 'class_section' ? input.sectionId! : null,
          title: input.title,
          body: input.body,
          expiresAt: input.expiresAt ? new Date(input.expiresAt) : null,
        })
        .returning({ id: announcements.id });

      if (!created) throw new ApiError(500, 'Unable to publish announcement');
      return (await this.listAdminAnnouncements(user)).find((item) => item.id === created.id) ?? created;
    },

    async listTeacherAnnouncements(user: AuthUser) {
      const assigned = await this.teacherAssignmentsFor(user);
      const activeTargets = new Set(assigned.map((assignment) => `${assignment.classId}:${assignment.sectionId}`));

      const rows = await db
        .select({
          announcement: announcements,
          className: classes.name,
          sectionName: sections.name,
          authorName: appUsers.displayName,
        })
        .from(announcements)
        .innerJoin(appUsers, eq(announcements.authorUserId, appUsers.id))
        .leftJoin(classes, eq(announcements.classId, classes.id))
        .leftJoin(sections, eq(announcements.sectionId, sections.id))
        .where(eq(announcements.schoolId, user.schoolId))
        .orderBy(desc(announcements.publishedAt))
        .limit(200);

      return rows
        .map(announcementWithLabels)
        .filter((item) => {
          if (item.expiresAt && new Date(`${item.expiresAt}`).getTime() < Date.now()) return false;
          if (item.audience === 'school') return true;
          return activeTargets.has(`${item.classId}:${item.sectionId}`);
        });
    },

    async createTeacherAnnouncement(user: AuthUser, input: AnnouncementInput) {
      if (!user.staffId) throw new ApiError(403, 'Teacher profile is required');
      if (input.audience !== 'class_section') {
        throw new ApiError(403, 'Teachers can publish announcements only to assigned class sections');
      }
      await assertTeacherAnnouncementTarget(db, user, input);

      const [created] = await db
        .insert(announcements)
        .values({
          schoolId: user.schoolId,
          authorUserId: user.appUserId,
          authorStaffId: user.staffId,
          audience: input.audience,
          priority: input.priority,
          classId: input.classId!,
          sectionId: input.sectionId!,
          title: input.title,
          body: input.body,
          expiresAt: input.expiresAt ? new Date(input.expiresAt) : null,
        })
        .returning({ id: announcements.id });

      if (!created) throw new ApiError(500, 'Unable to publish announcement');
      return (await this.listTeacherAnnouncements(user)).find((item) => item.id === created.id) ?? created;
    },

    async portalProfile(user: AuthUser) {
      const [school] = await db.select().from(schools).where(eq(schools.id, user.schoolId)).limit(1);
      const [activeAcademicYear] = await db
        .select()
        .from(academicYears)
        .where(and(eq(academicYears.schoolId, user.schoolId), eq(academicYears.isActive, true)))
        .limit(1);

      return {
        school,
        activeAcademicYear: activeAcademicYear ?? null,
        students: await portalStudentsFor(db, user),
      };
    },

    async portalAnnouncements(user: AuthUser, studentId?: string) {
      const portalStudents = await resolvePortalStudents(db, user, studentId);
      const targets = new Set(portalStudents.map((student) => `${student.classId}:${student.sectionId}`));

      const rows = await db
        .select({
          announcement: announcements,
          className: classes.name,
          sectionName: sections.name,
          authorName: appUsers.displayName,
        })
        .from(announcements)
        .innerJoin(appUsers, eq(announcements.authorUserId, appUsers.id))
        .leftJoin(classes, eq(announcements.classId, classes.id))
        .leftJoin(sections, eq(announcements.sectionId, sections.id))
        .where(eq(announcements.schoolId, user.schoolId))
        .orderBy(desc(announcements.publishedAt))
        .limit(200);

      return rows
        .map(announcementWithLabels)
        .filter((item) => {
          if (item.expiresAt && new Date(`${item.expiresAt}`).getTime() < Date.now()) return false;
          if (item.audience === 'school') return true;
          return targets.has(`${item.classId}:${item.sectionId}`);
        });
    },

    async portalAttendance(user: AuthUser, studentId?: string) {
      const portalStudent = await resolvePortalStudent(db, user, studentId);
      return this.studentAttendanceSummary(user, portalStudent.id);
    },

    async portalTimetable(user: AuthUser, studentId?: string) {
      const portalStudent = await resolvePortalStudent(db, user, studentId);
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
        .where(
          and(
            eq(timetableEntries.schoolId, user.schoolId),
            eq(timetableEntries.academicYearId, portalStudent.academicYearId),
            eq(timetableEntries.classId, portalStudent.classId),
            eq(timetableEntries.sectionId, portalStudent.sectionId),
          ),
        )
        .orderBy(timetableEntries.dayOfWeek, timetableEntries.startTime)
        .limit(100);

      return {
        student: portalStudent,
        entries: rows.map((r) => ({
          ...r.entry,
          className: r.className,
          sectionName: r.sectionName,
          subjectName: r.subjectName,
          staffName: r.staffName,
          academicYearName: r.academicYearName,
        })),
      };
    },

    async portalHomework(user: AuthUser, studentId?: string) {
      const portalStudent = await resolvePortalStudent(db, user, studentId);
      const rows = await db
        .select({
          assignment: homeworkAssignments,
          className: classes.name,
          sectionName: sections.name,
          subjectName: subjects.name,
          teacherName: staff.fullName,
        })
        .from(homeworkAssignments)
        .innerJoin(classes, eq(homeworkAssignments.classId, classes.id))
        .innerJoin(sections, eq(homeworkAssignments.sectionId, sections.id))
        .leftJoin(subjects, eq(homeworkAssignments.subjectId, subjects.id))
        .innerJoin(staff, eq(homeworkAssignments.ownerStaffId, staff.id))
        .where(
          and(
            eq(homeworkAssignments.schoolId, user.schoolId),
            eq(homeworkAssignments.academicYearId, portalStudent.academicYearId),
            eq(homeworkAssignments.classId, portalStudent.classId),
            eq(homeworkAssignments.sectionId, portalStudent.sectionId),
            eq(homeworkAssignments.status, 'published'),
          ),
        )
        .orderBy(desc(homeworkAssignments.dueDate), desc(homeworkAssignments.createdAt))
        .limit(100);

      return {
        student: portalStudent,
        assignments: rows.map(homeworkWithLabels),
      };
    },

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
      const [activeYear] = await db
        .select({ id: academicYears.id })
        .from(academicYears)
        .where(and(eq(academicYears.schoolId, user.schoolId), eq(academicYears.isActive, true)))
        .limit(1);

      return db
        .select({
          id: students.id,
          admissionNumber: students.admissionNumber,
          fullName: students.fullName,
          userId: students.userId,
          guardianName: students.guardianName,
          guardianPhone: students.guardianPhone,
          classId: studentEnrollments.classId,
          sectionId: studentEnrollments.sectionId,
          className: classes.name,
          sectionName: sections.name,
          academicYearId: studentEnrollments.academicYearId,
          rollNumber: studentEnrollments.rollNumber,
        })
        .from(students)
        .leftJoin(
          studentEnrollments,
          activeYear
            ? and(
                eq(studentEnrollments.studentId, students.id),
                eq(studentEnrollments.academicYearId, activeYear.id),
              )
            : eq(studentEnrollments.studentId, students.id),
        )
        .leftJoin(classes, eq(classes.id, studentEnrollments.classId))
        .leftJoin(sections, eq(sections.id, studentEnrollments.sectionId))
        .where(eq(students.schoolId, user.schoolId))
        .limit(500);
    },

    async createStudent(user: AuthUser, input: z.infer<typeof createStudentSchema>) {
      const [created] = await db
        .insert(students)
        .values({
          schoolId: user.schoolId,
          userId: input.userId ?? null,
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

    async createStudentGuardianLink(user: AuthUser, input: z.infer<typeof createStudentGuardianLinkSchema>) {
      await assertStudentAndUserBelongToSchool(db, user, input.studentId, input.appUserId);
      const [created] = await db
        .insert(studentGuardians)
        .values({
          schoolId: user.schoolId,
          studentId: input.studentId,
          appUserId: input.appUserId,
          relationship: input.relationship,
        })
        .returning();

      if (!created) throw new ApiError(500, 'Unable to link guardian account');
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
          subjectName: subjects.name,
        })
        .from(teacherAssignments)
        .innerJoin(classes, eq(teacherAssignments.classId, classes.id))
        .innerJoin(sections, eq(teacherAssignments.sectionId, sections.id))
        .leftJoin(subjects, eq(teacherAssignments.subjectId, subjects.id))
        .where(and(eq(teacherAssignments.schoolId, user.schoolId), eq(teacherAssignments.staffId, user.staffId)))
        .limit(100);

      return rows.map((r) => ({
        ...r.assignment,
        className: r.className,
        sectionName: r.sectionName,
        subjectName: r.subjectName,
      }));
    },

    async teacherTimetable(user: AuthUser, filters: TimetableFilters = {}) {
      if (!user.staffId) return [];
      return this.listTimetableEntries(user, {
        ...filters,
        staffId: user.staffId,
      });
    },

    async listTeacherMaterials(user: AuthUser) {
      if (!user.staffId) throw new ApiError(403, 'Teacher profile is required');
      const rows = await db
        .select({
          material: teacherMaterials,
          className: classes.name,
          sectionName: sections.name,
          subjectName: subjects.name,
        })
        .from(teacherMaterials)
        .leftJoin(classes, eq(teacherMaterials.classId, classes.id))
        .leftJoin(sections, eq(teacherMaterials.sectionId, sections.id))
        .leftJoin(subjects, eq(teacherMaterials.subjectId, subjects.id))
        .where(and(eq(teacherMaterials.schoolId, user.schoolId), eq(teacherMaterials.ownerStaffId, user.staffId)))
        .orderBy(desc(teacherMaterials.updatedAt))
        .limit(100);

      return rows.map(materialWithLabels);
    },

    async listTeacherHomework(user: AuthUser) {
      if (!user.staffId) throw new ApiError(403, 'Teacher profile is required');
      const rows = await db
        .select({
          assignment: homeworkAssignments,
          className: classes.name,
          sectionName: sections.name,
          subjectName: subjects.name,
          teacherName: staff.fullName,
        })
        .from(homeworkAssignments)
        .innerJoin(classes, eq(homeworkAssignments.classId, classes.id))
        .innerJoin(sections, eq(homeworkAssignments.sectionId, sections.id))
        .leftJoin(subjects, eq(homeworkAssignments.subjectId, subjects.id))
        .innerJoin(staff, eq(homeworkAssignments.ownerStaffId, staff.id))
        .where(and(eq(homeworkAssignments.schoolId, user.schoolId), eq(homeworkAssignments.ownerStaffId, user.staffId)))
        .orderBy(desc(homeworkAssignments.dueDate), desc(homeworkAssignments.createdAt))
        .limit(200);

      return rows.map(homeworkWithLabels);
    },

    async createTeacherHomework(user: AuthUser, input: HomeworkAssignmentInput) {
      if (!user.staffId) throw new ApiError(403, 'Teacher profile is required');
      await assertTeacherMaterialContext(db, user, input);

      const [created] = await db
        .insert(homeworkAssignments)
        .values({
          schoolId: user.schoolId,
          ownerStaffId: user.staffId,
          academicYearId: input.academicYearId,
          classId: input.classId,
          sectionId: input.sectionId,
          subjectId: input.subjectId ?? null,
          title: input.title,
          instructions: input.instructions,
          dueDate: input.dueDate,
          estimatedMinutes: input.estimatedMinutes ?? null,
          status: input.status,
          sourceMaterialId: input.sourceMaterialId ?? null,
        })
        .returning({ id: homeworkAssignments.id });

      if (!created) throw new ApiError(500, 'Unable to create homework assignment');
      return (await this.listTeacherHomework(user)).find((item) => item.id === created.id) ?? created;
    },

    async updateTeacherHomework(user: AuthUser, id: string, input: HomeworkAssignmentUpdateInput) {
      if (!user.staffId) throw new ApiError(403, 'Teacher profile is required');
      const [existing] = await db
        .select()
        .from(homeworkAssignments)
        .where(
          and(
            eq(homeworkAssignments.schoolId, user.schoolId),
            eq(homeworkAssignments.ownerStaffId, user.staffId),
            eq(homeworkAssignments.id, id),
          ),
        )
        .limit(1);
      if (!existing) throw new ApiError(404, 'Homework assignment not found');

      const next = {
        academicYearId: input.academicYearId ?? existing.academicYearId,
        classId: input.classId ?? existing.classId,
        sectionId: input.sectionId ?? existing.sectionId,
        subjectId: input.subjectId === undefined ? existing.subjectId : input.subjectId,
      };
      await assertTeacherMaterialContext(db, user, next);

      const [updated] = await db
        .update(homeworkAssignments)
        .set({
          ...input,
          subjectId: input.subjectId === undefined ? undefined : input.subjectId ?? null,
          estimatedMinutes: input.estimatedMinutes === undefined ? undefined : input.estimatedMinutes ?? null,
          sourceMaterialId: input.sourceMaterialId === undefined ? undefined : input.sourceMaterialId ?? null,
          updatedAt: new Date(),
        })
        .where(
          and(
            eq(homeworkAssignments.schoolId, user.schoolId),
            eq(homeworkAssignments.ownerStaffId, user.staffId),
            eq(homeworkAssignments.id, id),
          ),
        )
        .returning({ id: homeworkAssignments.id });

      if (!updated) throw new ApiError(500, 'Unable to update homework assignment');
      return (await this.listTeacherHomework(user)).find((item) => item.id === updated.id) ?? updated;
    },

    async deleteTeacherHomework(user: AuthUser, id: string) {
      if (!user.staffId) throw new ApiError(403, 'Teacher profile is required');
      const [deleted] = await db
        .delete(homeworkAssignments)
        .where(
          and(
            eq(homeworkAssignments.schoolId, user.schoolId),
            eq(homeworkAssignments.ownerStaffId, user.staffId),
            eq(homeworkAssignments.id, id),
          ),
        )
        .returning({ id: homeworkAssignments.id });

      if (!deleted) throw new ApiError(404, 'Homework assignment not found');
      return deleted;
    },

    async getTeacherMaterial(user: AuthUser, id: string) {
      if (!user.staffId) throw new ApiError(403, 'Teacher profile is required');
      const [row] = await db
        .select({
          material: teacherMaterials,
          className: classes.name,
          sectionName: sections.name,
          subjectName: subjects.name,
        })
        .from(teacherMaterials)
        .leftJoin(classes, eq(teacherMaterials.classId, classes.id))
        .leftJoin(sections, eq(teacherMaterials.sectionId, sections.id))
        .leftJoin(subjects, eq(teacherMaterials.subjectId, subjects.id))
        .where(
          and(
            eq(teacherMaterials.schoolId, user.schoolId),
            eq(teacherMaterials.ownerStaffId, user.staffId),
            eq(teacherMaterials.id, id),
          ),
        )
        .limit(1);

      if (!row) throw new ApiError(404, 'Teaching material not found');
      return materialWithLabels(row);
    },

    async createTeacherMaterial(user: AuthUser, input: TeacherMaterialInput) {
      if (!user.staffId) throw new ApiError(403, 'Teacher profile is required');
      await assertTeacherMaterialContext(db, user, input);

      const [created] = await db
        .insert(teacherMaterials)
        .values({
          schoolId: user.schoolId,
          ownerStaffId: user.staffId,
          academicYearId: input.academicYearId ?? null,
          classId: input.classId ?? null,
          sectionId: input.sectionId ?? null,
          subjectId: input.subjectId ?? null,
          type: input.type,
          title: input.title,
          topic: input.topic,
          difficulty: input.difficulty,
          language: input.language,
          durationMinutes: input.durationMinutes ?? null,
          questionCount: input.questionCount ?? null,
          content: input.content,
          metadata: input.metadata ?? {},
        })
        .returning();

      if (!created) throw new ApiError(500, 'Unable to save teaching material');
      return this.getTeacherMaterial(user, created.id);
    },

    async updateTeacherMaterial(user: AuthUser, id: string, input: TeacherMaterialUpdateInput) {
      const existing = await this.getTeacherMaterial(user, id);
      const next = {
        academicYearId: input.academicYearId ?? (existing.academicYearId as string | null) ?? undefined,
        classId: input.classId ?? (existing.classId as string | null) ?? undefined,
        sectionId: input.sectionId ?? (existing.sectionId as string | null) ?? undefined,
        subjectId: input.subjectId ?? (existing.subjectId as string | null) ?? undefined,
      };
      await assertTeacherMaterialContext(db, user, next);

      const [updated] = await db
        .update(teacherMaterials)
        .set({
          ...(input.type ? { type: input.type } : {}),
          ...(input.title ? { title: input.title } : {}),
          ...(input.topic ? { topic: input.topic } : {}),
          ...(input.difficulty ? { difficulty: input.difficulty } : {}),
          ...(input.language ? { language: input.language } : {}),
          ...(input.academicYearId !== undefined ? { academicYearId: input.academicYearId ?? null } : {}),
          ...(input.classId !== undefined ? { classId: input.classId ?? null } : {}),
          ...(input.sectionId !== undefined ? { sectionId: input.sectionId ?? null } : {}),
          ...(input.subjectId !== undefined ? { subjectId: input.subjectId ?? null } : {}),
          ...(input.durationMinutes !== undefined ? { durationMinutes: input.durationMinutes ?? null } : {}),
          ...(input.questionCount !== undefined ? { questionCount: input.questionCount ?? null } : {}),
          ...(input.content ? { content: input.content } : {}),
          ...(input.metadata ? { metadata: input.metadata } : {}),
          updatedAt: new Date(),
        })
        .where(
          and(
            eq(teacherMaterials.schoolId, user.schoolId),
            eq(teacherMaterials.ownerStaffId, user.staffId!),
            eq(teacherMaterials.id, id),
          ),
        )
        .returning({ id: teacherMaterials.id });

      if (!updated) throw new ApiError(404, 'Teaching material not found');
      return this.getTeacherMaterial(user, id);
    },

    async deleteTeacherMaterial(user: AuthUser, id: string) {
      if (!user.staffId) throw new ApiError(403, 'Teacher profile is required');
      const [deleted] = await db
        .delete(teacherMaterials)
        .where(
          and(
            eq(teacherMaterials.schoolId, user.schoolId),
            eq(teacherMaterials.ownerStaffId, user.staffId),
            eq(teacherMaterials.id, id),
          ),
        )
        .returning({ id: teacherMaterials.id });

      if (!deleted) throw new ApiError(404, 'Teaching material not found');
      return deleted;
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

    async attendanceInsightDataset(
      user: AuthUser,
      filters: {
        startDate: string;
        endDate: string;
        classId?: string | undefined;
        sectionId?: string | undefined;
      },
    ) {
      const previous = previousRange(filters.startDate, filters.endDate);
      const currentRows = await attendanceRows(db, user, filters);
      const previousRows = await attendanceRows(db, user, {
        ...filters,
        startDate: previous.startDate,
        endDate: previous.endDate,
      });
      const expected = await expectedTimetableSessions(db, user, filters);

      const currentMetrics = summarizeAttendanceRows(currentRows, expected.total);
      const previousMetrics = summarizeAttendanceRows(previousRows, 0);
      const sectionMetrics = sectionBreakdown(currentRows, previousRows, expected.bySection);

      return {
        range: filters,
        previousRange: previous,
        metrics: currentMetrics,
        previousMetrics,
        sectionMetrics,
        generatedAt: new Date().toISOString(),
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

type PortalStudent = {
  id: string;
  fullName: string;
  admissionNumber: string;
  relationship: string;
  academicYearId: string;
  academicYearName: string;
  classId: string;
  className: string;
  sectionId: string;
  sectionName: string;
  rollNumber: string | null;
};

async function portalStudentsFor(db: Db, user: AuthUser): Promise<PortalStudent[]> {
  const directRows = await db
    .select({
      id: students.id,
      fullName: students.fullName,
      admissionNumber: students.admissionNumber,
      academicYearId: studentEnrollments.academicYearId,
      academicYearName: academicYears.name,
      classId: studentEnrollments.classId,
      className: classes.name,
      sectionId: studentEnrollments.sectionId,
      sectionName: sections.name,
      rollNumber: studentEnrollments.rollNumber,
    })
    .from(students)
    .innerJoin(studentEnrollments, eq(studentEnrollments.studentId, students.id))
    .innerJoin(academicYears, eq(studentEnrollments.academicYearId, academicYears.id))
    .innerJoin(classes, eq(studentEnrollments.classId, classes.id))
    .innerJoin(sections, eq(studentEnrollments.sectionId, sections.id))
    .where(
      and(
        eq(students.schoolId, user.schoolId),
        eq(students.userId, user.appUserId),
        eq(students.isActive, true),
        eq(studentEnrollments.schoolId, user.schoolId),
        eq(academicYears.schoolId, user.schoolId),
        eq(academicYears.isActive, true),
        eq(classes.schoolId, user.schoolId),
        eq(sections.schoolId, user.schoolId),
      ),
    )
    .limit(20);

  const guardianRows = await db
    .select({
      id: students.id,
      fullName: students.fullName,
      admissionNumber: students.admissionNumber,
      relationship: studentGuardians.relationship,
      academicYearId: studentEnrollments.academicYearId,
      academicYearName: academicYears.name,
      classId: studentEnrollments.classId,
      className: classes.name,
      sectionId: studentEnrollments.sectionId,
      sectionName: sections.name,
      rollNumber: studentEnrollments.rollNumber,
    })
    .from(studentGuardians)
    .innerJoin(students, eq(studentGuardians.studentId, students.id))
    .innerJoin(studentEnrollments, eq(studentEnrollments.studentId, students.id))
    .innerJoin(academicYears, eq(studentEnrollments.academicYearId, academicYears.id))
    .innerJoin(classes, eq(studentEnrollments.classId, classes.id))
    .innerJoin(sections, eq(studentEnrollments.sectionId, sections.id))
    .where(
      and(
        eq(studentGuardians.schoolId, user.schoolId),
        eq(studentGuardians.appUserId, user.appUserId),
        eq(students.schoolId, user.schoolId),
        eq(students.isActive, true),
        eq(studentEnrollments.schoolId, user.schoolId),
        eq(academicYears.schoolId, user.schoolId),
        eq(academicYears.isActive, true),
        eq(classes.schoolId, user.schoolId),
        eq(sections.schoolId, user.schoolId),
      ),
    )
    .limit(50);

  const deduped = new Map<string, PortalStudent>();
  for (const row of directRows) {
    deduped.set(row.id, { ...row, relationship: 'self' });
  }
  for (const row of guardianRows) {
    if (!deduped.has(row.id)) deduped.set(row.id, row);
  }
  return [...deduped.values()];
}

async function resolvePortalStudents(db: Db, user: AuthUser, studentId?: string): Promise<PortalStudent[]> {
  const students = await portalStudentsFor(db, user);
  if (students.length === 0) throw new ApiError(404, 'No linked student profile is available for this account');
  if (!studentId) return students;
  const selected = students.find((student) => student.id === studentId);
  if (!selected) throw new ApiError(403, 'This student profile is not linked to your account');
  return [selected];
}

async function resolvePortalStudent(db: Db, user: AuthUser, studentId?: string): Promise<PortalStudent> {
  return (await resolvePortalStudents(db, user, studentId))[0]!;
}

type AttendanceInsightRow = {
  sessionId: string;
  attendanceDate: string;
  kind: 'daily' | 'period';
  periodNumber: number | null;
  classId: string;
  sectionId: string;
  subjectId: string | null;
  className: string;
  sectionName: string;
  status: 'present' | 'absent' | 'late' | 'excused';
};

async function attendanceRows(
  db: Db,
  user: AuthUser,
  filters: {
    startDate: string;
    endDate: string;
    classId?: string | undefined;
    sectionId?: string | undefined;
  },
): Promise<AttendanceInsightRow[]> {
  const conditions = [
    eq(attendanceSessions.schoolId, user.schoolId),
    gte(attendanceSessions.attendanceDate, filters.startDate),
    lte(attendanceSessions.attendanceDate, filters.endDate),
  ];
  if (filters.classId) conditions.push(eq(attendanceSessions.classId, filters.classId));
  if (filters.sectionId) conditions.push(eq(attendanceSessions.sectionId, filters.sectionId));

  const rows = await db
    .select({
      sessionId: attendanceSessions.id,
      attendanceDate: attendanceSessions.attendanceDate,
      kind: attendanceSessions.kind,
      periodNumber: attendanceSessions.periodNumber,
      classId: attendanceSessions.classId,
      sectionId: attendanceSessions.sectionId,
      subjectId: attendanceSessions.subjectId,
      className: classes.name,
      sectionName: sections.name,
      status: attendanceRecords.status,
    })
    .from(attendanceRecords)
    .innerJoin(attendanceSessions, eq(attendanceRecords.sessionId, attendanceSessions.id))
    .innerJoin(classes, eq(attendanceSessions.classId, classes.id))
    .innerJoin(sections, eq(attendanceSessions.sectionId, sections.id))
    .where(and(...conditions))
    .limit(5000);

  return rows;
}

async function expectedTimetableSessions(
  db: Db,
  user: AuthUser,
  filters: {
    startDate: string;
    endDate: string;
    classId?: string | undefined;
    sectionId?: string | undefined;
  },
) {
  const conditions = [eq(timetableEntries.schoolId, user.schoolId)];
  if (filters.classId) conditions.push(eq(timetableEntries.classId, filters.classId));
  if (filters.sectionId) conditions.push(eq(timetableEntries.sectionId, filters.sectionId));

  const entries = await db
    .select({
      sectionId: timetableEntries.sectionId,
      dayOfWeek: timetableEntries.dayOfWeek,
    })
    .from(timetableEntries)
    .where(and(...conditions))
    .limit(1000);

  const bySection = new Map<string, number>();
  let total = 0;
  for (const date of datesBetween(filters.startDate, filters.endDate)) {
    const day = schoolicDayOfWeek(date);
    for (const entry of entries) {
      if (entry.dayOfWeek !== day) continue;
      total++;
      bySection.set(entry.sectionId, (bySection.get(entry.sectionId) ?? 0) + 1);
    }
  }

  return { total, bySection };
}

function summarizeAttendanceRows(rows: AttendanceInsightRow[], expectedSessions: number) {
  const sessions = new Set(rows.map((row) => row.sessionId));
  const counts = { present: 0, absent: 0, late: 0, excused: 0 };
  for (const row of rows) counts[row.status]++;
  const totalRecords = counts.present + counts.absent + counts.late + counts.excused;
  const attendancePercentage = totalRecords === 0 ? null : Math.round(((counts.present + counts.late) / totalRecords) * 1000) / 10;
  return {
    submittedSessions: sessions.size,
    expectedSessions,
    pendingSessions: Math.max(expectedSessions - sessions.size, 0),
    totalRecords,
    ...counts,
    attendancePercentage,
    denominator: 'present + absent + late + excused attendance records; late counts as attended',
  };
}

function sectionBreakdown(
  currentRows: AttendanceInsightRow[],
  previousRows: AttendanceInsightRow[],
  expectedBySection: Map<string, number>,
) {
  const current = groupBySection(currentRows);
  const previous = groupBySection(previousRows);
  return [...current.values()]
    .map((section) => {
      const prev = previous.get(section.sectionId);
      const expected = expectedBySection.get(section.sectionId) ?? 0;
      return {
        ...section,
        expectedSessions: expected,
        pendingSessions: Math.max(expected - section.submittedSessions, 0),
        previousAttendancePercentage: prev?.attendancePercentage ?? null,
        attendanceChangePoints:
          section.attendancePercentage === null || prev?.attendancePercentage === null || prev?.attendancePercentage === undefined
            ? null
            : Math.round((section.attendancePercentage - prev.attendancePercentage) * 10) / 10,
      };
    })
    .sort((a, b) => (a.attendancePercentage ?? 101) - (b.attendancePercentage ?? 101))
    .slice(0, 10);
}

function groupBySection(rows: AttendanceInsightRow[]) {
  const map = new Map<
    string,
    {
      sectionId: string;
      label: string;
      submittedSessions: number;
      totalRecords: number;
      present: number;
      absent: number;
      late: number;
      excused: number;
      attendancePercentage: number | null;
    }
  >();
  const sessionsBySection = new Map<string, Set<string>>();

  for (const row of rows) {
    if (!map.has(row.sectionId)) {
      map.set(row.sectionId, {
        sectionId: row.sectionId,
        label: `${row.className} ${row.sectionName}`,
        submittedSessions: 0,
        totalRecords: 0,
        present: 0,
        absent: 0,
        late: 0,
        excused: 0,
        attendancePercentage: null,
      });
      sessionsBySection.set(row.sectionId, new Set());
    }
    const item = map.get(row.sectionId)!;
    sessionsBySection.get(row.sectionId)!.add(row.sessionId);
    item.totalRecords++;
    item[row.status]++;
  }

  for (const [sectionId, item] of map.entries()) {
    item.submittedSessions = sessionsBySection.get(sectionId)?.size ?? 0;
    item.attendancePercentage =
      item.totalRecords === 0 ? null : Math.round(((item.present + item.late) / item.totalRecords) * 1000) / 10;
  }

  return map;
}

function previousRange(startDate: string, endDate: string) {
  const start = parseDate(startDate);
  const end = parseDate(endDate);
  const days = Math.max(1, Math.round((end.getTime() - start.getTime()) / 86400000) + 1);
  const previousEnd = new Date(start);
  previousEnd.setUTCDate(previousEnd.getUTCDate() - 1);
  const previousStart = new Date(previousEnd);
  previousStart.setUTCDate(previousStart.getUTCDate() - days + 1);
  return { startDate: toIsoDate(previousStart), endDate: toIsoDate(previousEnd) };
}

function datesBetween(startDate: string, endDate: string) {
  const dates: Date[] = [];
  const cursor = parseDate(startDate);
  const end = parseDate(endDate);
  while (cursor <= end) {
    dates.push(new Date(cursor));
    cursor.setUTCDate(cursor.getUTCDate() + 1);
  }
  return dates;
}

function schoolicDayOfWeek(date: Date) {
  const day = date.getUTCDay();
  return day === 0 ? 7 : day;
}

function parseDate(value: string) {
  return new Date(`${value}T00:00:00.000Z`);
}

function toIsoDate(value: Date) {
  return value.toISOString().slice(0, 10);
}

function materialWithLabels(row: {
  material: typeof teacherMaterials.$inferSelect;
  className: string | null;
  sectionName: string | null;
  subjectName: string | null;
}) {
  return {
    ...row.material,
    className: row.className,
    sectionName: row.sectionName,
    subjectName: row.subjectName,
  };
}

function homeworkWithLabels(row: {
  assignment: typeof homeworkAssignments.$inferSelect;
  className: string;
  sectionName: string;
  subjectName: string | null;
  teacherName: string;
}) {
  return {
    ...row.assignment,
    className: row.className,
    sectionName: row.sectionName,
    subjectName: row.subjectName,
    teacherName: row.teacherName,
  };
}

function announcementWithLabels(row: {
  announcement: typeof announcements.$inferSelect;
  className: string | null;
  sectionName: string | null;
  authorName: string | null;
}) {
  return {
    ...row.announcement,
    className: row.className,
    sectionName: row.sectionName,
    authorName: row.authorName,
  };
}

async function assertAnnouncementTarget(db: Db, user: AuthUser, input: AnnouncementInput) {
  if (input.audience === 'school') return;
  const [target] = await db
    .select({ id: sections.id })
    .from(sections)
    .where(
      and(
        eq(sections.schoolId, user.schoolId),
        eq(sections.id, input.sectionId!),
        eq(sections.classId, input.classId!),
      ),
    )
    .limit(1);

  if (!target) throw new ApiError(422, 'Selected class section is not available');
}

async function assertStudentAndUserBelongToSchool(db: Db, user: AuthUser, studentId: string, appUserId: string) {
  const [student] = await db
    .select({ id: students.id })
    .from(students)
    .where(and(eq(students.schoolId, user.schoolId), eq(students.id, studentId), eq(students.isActive, true)))
    .limit(1);
  if (!student) throw new ApiError(422, 'Selected student is not available');

  const [appUser] = await db
    .select({ id: appUsers.id })
    .from(appUsers)
    .where(and(eq(appUsers.schoolId, user.schoolId), eq(appUsers.id, appUserId), eq(appUsers.isActive, true)))
    .limit(1);
  if (!appUser) throw new ApiError(422, 'Selected user account is not available');
}

async function assertTeacherAnnouncementTarget(db: Db, user: AuthUser, input: AnnouncementInput) {
  await assertAnnouncementTarget(db, user, input);
  const [assigned] = await db
    .select({ id: teacherAssignments.id })
    .from(teacherAssignments)
    .where(
      and(
        eq(teacherAssignments.schoolId, user.schoolId),
        eq(teacherAssignments.staffId, user.staffId!),
        eq(teacherAssignments.classId, input.classId!),
        eq(teacherAssignments.sectionId, input.sectionId!),
      ),
    )
    .limit(1);

  if (!assigned) throw new ApiError(403, 'Teacher is not assigned to this class section');
}

function summarizeAiUsage(rows: Array<typeof aiUsageEvents.$inferSelect>) {
  const byFeature = new Map<string, { feature: string; requests: number; successes: number; failures: number; inputTokens: number | null; outputTokens: number | null; totalTokens: number | null; averageLatencyMs: number | null }>();
  const byGenerationType = new Map<string, { generationType: string; requests: number; successes: number; failures: number }>();
  const daily = new Map<string, { date: string; requests: number; successes: number; failures: number }>();
  let successes = 0;
  let failures = 0;
  let limited = 0;
  let inputTokens: number | null = null;
  let outputTokens: number | null = null;
  let totalTokens: number | null = null;
  let latencyTotal = 0;
  let latencyCount = 0;

  const addTokens = (current: number | null, value: number | null) => (value === null ? current : (current ?? 0) + value);

  for (const row of rows) {
    if (row.status === 'success') successes++;
    else if (row.status === 'limited') limited++;
    else failures++;

    inputTokens = addTokens(inputTokens, row.inputTokens);
    outputTokens = addTokens(outputTokens, row.outputTokens);
    totalTokens = addTokens(totalTokens, row.totalTokens);
    if (row.latencyMs !== null) {
      latencyTotal += row.latencyMs;
      latencyCount++;
    }

    const feature = byFeature.get(row.feature) ?? {
      feature: row.feature,
      requests: 0,
      successes: 0,
      failures: 0,
      inputTokens: null,
      outputTokens: null,
      totalTokens: null,
      averageLatencyMs: null,
    };
    feature.requests++;
    if (row.status === 'success') feature.successes++;
    else feature.failures++;
    feature.inputTokens = addTokens(feature.inputTokens, row.inputTokens);
    feature.outputTokens = addTokens(feature.outputTokens, row.outputTokens);
    feature.totalTokens = addTokens(feature.totalTokens, row.totalTokens);
    byFeature.set(row.feature, feature);

    if (row.generationType) {
      const type = byGenerationType.get(row.generationType) ?? {
        generationType: row.generationType,
        requests: 0,
        successes: 0,
        failures: 0,
      };
      type.requests++;
      if (row.status === 'success') type.successes++;
      else type.failures++;
      byGenerationType.set(row.generationType, type);
    }

    const day = row.createdAt.toISOString().slice(0, 10);
    const bucket = daily.get(day) ?? { date: day, requests: 0, successes: 0, failures: 0 };
    bucket.requests++;
    if (row.status === 'success') bucket.successes++;
    else bucket.failures++;
    daily.set(day, bucket);
  }

  return {
    totals: {
      requests: rows.length,
      successes,
      failures,
      limited,
      inputTokens,
      outputTokens,
      totalTokens,
      averageLatencyMs: latencyCount === 0 ? null : Math.round(latencyTotal / latencyCount),
    },
    byFeature: [...byFeature.values()],
    byGenerationType: [...byGenerationType.values()],
    daily: [...daily.values()].sort((a, b) => a.date.localeCompare(b.date)),
  };
}

async function assertTeacherMaterialContext(
  db: Db,
  user: AuthUser,
  input: {
    academicYearId?: string | undefined;
    classId?: string | undefined;
    sectionId?: string | undefined;
    subjectId?: string | null | undefined;
  },
) {
  if (!user.staffId) throw new ApiError(403, 'Teacher profile is required');
  if (!input.academicYearId && !input.classId && !input.sectionId && !input.subjectId) return;

  const conditions = [eq(teacherAssignments.schoolId, user.schoolId), eq(teacherAssignments.staffId, user.staffId)];
  if (input.academicYearId) conditions.push(eq(teacherAssignments.academicYearId, input.academicYearId));
  if (input.classId) conditions.push(eq(teacherAssignments.classId, input.classId));
  if (input.sectionId) conditions.push(eq(teacherAssignments.sectionId, input.sectionId));
  if (input.subjectId) conditions.push(eq(teacherAssignments.subjectId, input.subjectId));

  const [assignment] = await db.select({ id: teacherAssignments.id }).from(teacherAssignments).where(and(...conditions)).limit(1);
  if (!assignment) {
    throw new ApiError(403, 'Selected class, section, or subject is not assigned to this teacher.');
  }
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
