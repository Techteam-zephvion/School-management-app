import { and, desc, eq, gte, lte, ne, sql } from 'drizzle-orm';
import type { Db } from '../db/client';
import {
  academicYears,
  admissionApplications,
  admissionDocuments,
  aiUsageEvents,
  announcements,
  appUsers,
  attendanceRecords,
  attendanceSessions,
  classes,
  examMarks,
  exams,
  feePayments,
  feeStructures,
  homeworkAssignments,
  homeworkSubmissions,
  schools,
  sections,
  staff,
  studentEnrollments,
  studentFeeAllocations,
  studentGuardians,
  students,
  subjects,
  teacherMaterials,
  timetableEntries,
  teacherAssignments,
  userRoles,
  paymentOrders,
  paymentWebhookEvents,
  notifications,
  chatConversations,
  chatMessages,
  teacherAvailabilitySettings,
  dpdpConsents,
  auditLogs,
  dataSubjectRequests,
  feeStructureHeads,
  feeConcessions,
  studentFeeConcessions,
  feeRefunds,
} from '../db/schema';

import { BulkImporter } from '../importers/bulk-importer';
import { NotificationService } from '../notifications/notification-service';
import { ApiError } from '../http/errors';
import { CashfreeClient } from '../payments/cashfree';
import type { AuthUser, Env } from '../types';
import type {
  createAcademicYearSchema,
  createAnnouncementSchema,
  createHomeworkAssignmentSchema,
  createExamSchema,
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
  submitHomeworkSchema,
  timetableQuerySchema,
  updateTeacherMaterialSchema,
  updateHomeworkAssignmentSchema,
  gradeHomeworkSubmissionSchema,
  updateExamSchema,
  saveExamMarksSchema,
  updateTimetableEntrySchema,
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
  createChatConversationSchema,
  sendChatMessageSchema,
  updateTeacherAvailabilitySchema,
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
type ExamInput = z.infer<typeof createExamSchema>;
type ExamUpdateInput = z.infer<typeof updateExamSchema>;
type FeeStructureInput = z.infer<typeof createFeeStructureSchema>;
type FeeStructureUpdateInput = z.infer<typeof updateFeeStructureSchema>;
type FeeAllocationInput = z.infer<typeof createFeeAllocationSchema>;
type FeePaymentInput = z.infer<typeof recordFeePaymentSchema>;
type FeeAllocationFilters = z.infer<typeof feeAllocationQuerySchema>;
type FeePaymentFilters = z.infer<typeof feePaymentQuerySchema>;
type AdmissionApplicationInput = z.infer<typeof createAdmissionApplicationSchema>;
type AdmissionApplicationUpdateInput = z.infer<typeof updateAdmissionApplicationSchema>;
type EnrollApplicantInput = z.infer<typeof enrollApplicantSchema>;
type AdmissionQueryFilters = z.infer<typeof admissionQuerySchema>;
type AddAdmissionDocumentInput = z.infer<typeof addAdmissionDocumentSchema>;
type UpdateAdmissionDocumentInput = z.infer<typeof updateAdmissionDocumentSchema>;

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
          submission: homeworkSubmissions,
        })
        .from(homeworkAssignments)
        .innerJoin(classes, eq(homeworkAssignments.classId, classes.id))
        .innerJoin(sections, eq(homeworkAssignments.sectionId, sections.id))
        .leftJoin(subjects, eq(homeworkAssignments.subjectId, subjects.id))
        .innerJoin(staff, eq(homeworkAssignments.ownerStaffId, staff.id))
        .leftJoin(
          homeworkSubmissions,
          and(
            eq(homeworkSubmissions.assignmentId, homeworkAssignments.id),
            eq(homeworkSubmissions.studentId, portalStudent.id),
          ),
        )
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

    async portalSubmitHomework(
      user: AuthUser,
      assignmentId: string,
      input: z.infer<typeof submitHomeworkSchema>,
    ) {
      const portalStudent = await resolvePortalStudent(db, user, input.studentId);
      const [assignment] = await db
        .select()
        .from(homeworkAssignments)
        .where(
          and(
            eq(homeworkAssignments.id, assignmentId),
            eq(homeworkAssignments.schoolId, user.schoolId),
            eq(homeworkAssignments.academicYearId, portalStudent.academicYearId),
            eq(homeworkAssignments.classId, portalStudent.classId),
            eq(homeworkAssignments.sectionId, portalStudent.sectionId),
            eq(homeworkAssignments.status, 'published'),
          ),
        )
        .limit(1);

      if (!assignment) {
        throw new ApiError(404, 'Homework assignment not found or not assigned to this student');
      }

      const [existing] = await db
        .select()
        .from(homeworkSubmissions)
        .where(
          and(
            eq(homeworkSubmissions.assignmentId, assignmentId),
            eq(homeworkSubmissions.studentId, portalStudent.id),
          ),
        )
        .limit(1);

      if (existing) {
        const [updated] = await db
          .update(homeworkSubmissions)
          .set({
            content: input.content,
            attachmentUrl: input.attachmentUrl ?? null,
            status: existing.status === 'reviewed' ? 'resubmitted' : 'submitted',
            submittedAt: new Date(),
            updatedAt: new Date(),
          })
          .where(eq(homeworkSubmissions.id, existing.id))
          .returning();
        return updated;
      }

      const [created] = await db
        .insert(homeworkSubmissions)
        .values({
          schoolId: user.schoolId,
          assignmentId,
          studentId: portalStudent.id,
          content: input.content,
          attachmentUrl: input.attachmentUrl ?? null,
          status: 'submitted',
        })
        .returning();
      return created;
    },

    async portalIdCard(user: AuthUser, studentId?: string) {
      const portalStudent = await resolvePortalStudent(db, user, studentId);
      const [school] = await db.select().from(schools).where(eq(schools.id, user.schoolId)).limit(1);
      const [studentDetail] = await db
        .select()
        .from(students)
        .where(eq(students.id, portalStudent.id))
        .limit(1);

      const verificationPayload = {
        app: 'Schoolic',
        type: 'STUDENT_DIGITAL_ID',
        schoolCode: school?.code ?? 'SCH',
        schoolName: school?.name ?? 'Schoolic',
        studentId: portalStudent.id,
        admissionNumber: portalStudent.admissionNumber,
        fullName: portalStudent.fullName,
        className: portalStudent.className,
        sectionName: portalStudent.sectionName,
        academicYear: portalStudent.academicYearName,
        verifiedAt: new Date().toISOString(),
      };

      return {
        school: {
          name: school?.name ?? 'Schoolic',
          code: school?.code ?? 'SCH',
        },
        student: {
          ...portalStudent,
          guardianName: studentDetail?.guardianName ?? null,
          guardianPhone: studentDetail?.guardianPhone ?? null,
        },
        qrPayload: JSON.stringify(verificationPayload),
      };
    },

    async portalReportCard(user: AuthUser, studentId?: string) {
      const portalStudent = await resolvePortalStudent(db, user, studentId);
      const rows = await db
        .select({
          exam: exams,
          mark: examMarks,
          subjectName: subjects.name,
          teacherName: staff.fullName,
        })
        .from(examMarks)
        .innerJoin(exams, eq(examMarks.examId, exams.id))
        .leftJoin(subjects, eq(exams.subjectId, subjects.id))
        .innerJoin(staff, eq(examMarks.recordedByStaffId, staff.id))
        .where(
          and(
            eq(examMarks.schoolId, user.schoolId),
            eq(examMarks.studentId, portalStudent.id),
            eq(exams.schoolId, user.schoolId),
            eq(exams.academicYearId, portalStudent.academicYearId),
            eq(exams.status, 'published'),
          ),
        )
        .orderBy(desc(exams.examDate), desc(examMarks.updatedAt))
        .limit(200);

      const results = rows.map((row) => examResultWithLabels(row));
      const totalObtained = results.reduce((sum, result) => sum + result.marksObtained, 0);
      const totalMax = results.reduce((sum, result) => sum + result.maxMarks, 0);
      return {
        student: portalStudent,
        summary: {
          exams: results.length,
          totalObtained,
          totalMax,
          percentage: totalMax === 0 ? null : Math.round((totalObtained / totalMax) * 1000) / 10,
        },
        results,
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

    async listAdminExams(user: AuthUser) {
      const rows = await db
        .select({
          exam: exams,
          className: classes.name,
          sectionName: sections.name,
          subjectName: subjects.name,
        })
        .from(exams)
        .innerJoin(classes, eq(exams.classId, classes.id))
        .innerJoin(sections, eq(exams.sectionId, sections.id))
        .leftJoin(subjects, eq(exams.subjectId, subjects.id))
        .where(eq(exams.schoolId, user.schoolId))
        .orderBy(desc(exams.examDate), desc(exams.createdAt))
        .limit(300);

      return rows.map(examWithLabels);
    },

    async createAdminExam(user: AuthUser, input: ExamInput) {
      await assertExamContext(db, user, input);
      const [created] = await db
        .insert(exams)
        .values({ ...input, schoolId: user.schoolId, subjectId: input.subjectId ?? null })
        .returning({ id: exams.id });
      if (!created) throw new ApiError(500, 'Unable to create exam');
      return (await this.listAdminExams(user)).find((item) => item.id === created.id) ?? created;
    },

    async updateAdminExam(user: AuthUser, id: string, input: ExamUpdateInput) {
      const [existing] = await db
        .select()
        .from(exams)
        .where(and(eq(exams.schoolId, user.schoolId), eq(exams.id, id)))
        .limit(1);
      if (!existing) throw new ApiError(404, 'Exam not found');
      await assertExamContext(db, user, {
        academicYearId: input.academicYearId ?? existing.academicYearId,
        classId: input.classId ?? existing.classId,
        sectionId: input.sectionId ?? existing.sectionId,
        subjectId: input.subjectId === undefined ? existing.subjectId : input.subjectId,
      });
      const [updated] = await db
        .update(exams)
        .set({
          ...input,
          subjectId: input.subjectId === undefined ? undefined : input.subjectId ?? null,
          updatedAt: new Date(),
        })
        .where(and(eq(exams.schoolId, user.schoolId), eq(exams.id, id)))
        .returning({ id: exams.id });
      if (!updated) throw new ApiError(500, 'Unable to update exam');
      return (await this.listAdminExams(user)).find((item) => item.id === updated.id) ?? updated;
    },

    async deleteAdminExam(user: AuthUser, id: string) {
      const [deleted] = await db
        .delete(exams)
        .where(and(eq(exams.schoolId, user.schoolId), eq(exams.id, id)))
        .returning({ id: exams.id });
      if (!deleted) throw new ApiError(404, 'Exam not found');
      return deleted;
    },

    async listTeacherExams(user: AuthUser) {
      if (!user.staffId) throw new ApiError(403, 'Teacher profile is required');
      const assignments = await this.teacherAssignmentsFor(user);
      const allowed = new Set(assignments.map((assignment) => examContextKey(assignment)));
      const rows = await db
        .select({
          exam: exams,
          className: classes.name,
          sectionName: sections.name,
          subjectName: subjects.name,
        })
        .from(exams)
        .innerJoin(classes, eq(exams.classId, classes.id))
        .innerJoin(sections, eq(exams.sectionId, sections.id))
        .leftJoin(subjects, eq(exams.subjectId, subjects.id))
        .where(eq(exams.schoolId, user.schoolId))
        .orderBy(desc(exams.examDate), desc(exams.createdAt))
        .limit(300);

      return rows.map(examWithLabels).filter((exam) => allowed.has(examContextKey(exam)));
    },

    async examRosterForTeacher(user: AuthUser, examId: string) {
      const exam = await assertTeacherCanManageExam(db, user, examId);
      const rows = await db
        .select({
          studentId: students.id,
          admissionNumber: students.admissionNumber,
          fullName: students.fullName,
          rollNumber: studentEnrollments.rollNumber,
          mark: examMarks,
        })
        .from(studentEnrollments)
        .innerJoin(students, eq(studentEnrollments.studentId, students.id))
        .leftJoin(examMarks, and(eq(examMarks.examId, examId), eq(examMarks.studentId, students.id)))
        .where(
          and(
            eq(studentEnrollments.schoolId, user.schoolId),
            eq(studentEnrollments.academicYearId, exam.academicYearId),
            eq(studentEnrollments.classId, exam.classId),
            eq(studentEnrollments.sectionId, exam.sectionId),
            eq(students.isActive, true),
          ),
        )
        .orderBy(studentEnrollments.rollNumber, students.fullName)
        .limit(300);
      return {
        exam,
        students: rows.map((row) => ({
          studentId: row.studentId,
          admissionNumber: row.admissionNumber,
          fullName: row.fullName,
          rollNumber: row.rollNumber,
          marksObtained: row.mark?.marksObtained ?? null,
          remarks: row.mark?.remarks ?? null,
        })),
      };
    },

    async saveTeacherExamMarks(user: AuthUser, input: z.infer<typeof saveExamMarksSchema>) {
      const exam = await assertTeacherCanManageExam(db, user, input.examId);
      if (!user.staffId) throw new ApiError(403, 'Teacher profile is required');
      const validStudentIds = new Set(
        (
          await db
            .select({ id: students.id })
            .from(studentEnrollments)
            .innerJoin(students, eq(studentEnrollments.studentId, students.id))
            .where(
              and(
                eq(studentEnrollments.schoolId, user.schoolId),
                eq(studentEnrollments.academicYearId, exam.academicYearId),
                eq(studentEnrollments.classId, exam.classId),
                eq(studentEnrollments.sectionId, exam.sectionId),
                eq(students.isActive, true),
              ),
            )
            .limit(300)
        ).map((row) => row.id),
      );
      for (const record of input.records) {
        if (!validStudentIds.has(record.studentId)) throw new ApiError(403, 'One or more students do not belong to this exam section');
        if (record.marksObtained > exam.maxMarks) throw new ApiError(422, 'Marks cannot exceed exam maximum marks');
      }

      await db
        .insert(examMarks)
        .values(
          input.records.map((record) => ({
            schoolId: user.schoolId,
            examId: input.examId,
            studentId: record.studentId,
            recordedByStaffId: user.staffId!,
            marksObtained: record.marksObtained,
            remarks: record.remarks ?? null,
          })),
        )
        .onConflictDoUpdate({
          target: [examMarks.examId, examMarks.studentId],
          set: {
            recordedByStaffId: user.staffId,
            marksObtained: sqlExcluded('marks_obtained'),
            remarks: sqlExcluded('remarks'),
            updatedAt: new Date(),
          },
        });

      return this.examRosterForTeacher(user, input.examId);
    },

    async feeSummary(user: AuthUser) {
      const allocations = await db
        .select()
        .from(studentFeeAllocations)
        .where(eq(studentFeeAllocations.schoolId, user.schoolId));

      const payments = await db
        .select()
        .from(feePayments)
        .where(eq(feePayments.schoolId, user.schoolId));

      let totalBilled = 0;
      let overdueCount = 0;
      const today = new Date().toISOString().slice(0, 10);

      for (const a of allocations) {
        totalBilled += a.amount;
        if (a.status === 'overdue' || (a.status !== 'paid' && a.dueDate < today)) {
          overdueCount++;
        }
      }

      let totalCollected = 0;
      for (const p of payments) {
        totalCollected += p.amountPaid;
      }

      const totalOutstanding = Math.max(0, totalBilled - totalCollected);

      return {
        totalBilled,
        totalCollected,
        totalOutstanding,
        overdueCount,
        allocationCount: allocations.length,
        paymentCount: payments.length,
      };
    },

    async listFeeStructures(user: AuthUser, academicYearId?: string) {
      const conditions = [eq(feeStructures.schoolId, user.schoolId)];
      if (academicYearId) conditions.push(eq(feeStructures.academicYearId, academicYearId));

      const rows = await db
        .select({
          structure: feeStructures,
          academicYearName: academicYears.name,
        })
        .from(feeStructures)
        .innerJoin(academicYears, eq(feeStructures.academicYearId, academicYears.id))
        .where(and(...conditions))
        .orderBy(desc(feeStructures.createdAt))
        .limit(200);

      return rows.map((r) => ({
        ...r.structure,
        academicYearName: r.academicYearName,
      }));
    },

    async createFeeStructure(user: AuthUser, input: FeeStructureInput) {
      const [year] = await db
        .select({ id: academicYears.id })
        .from(academicYears)
        .where(and(eq(academicYears.schoolId, user.schoolId), eq(academicYears.id, input.academicYearId)))
        .limit(1);
      if (!year) throw new ApiError(422, 'Selected academic year is not available');

      const [created] = await db
        .insert(feeStructures)
        .values({
          ...input,
          schoolId: user.schoolId,
          description: input.description ?? null,
          dueDate: input.dueDate ?? null,
        })
        .returning({ id: feeStructures.id });
      if (!created) throw new ApiError(500, 'Unable to create fee structure');

      return (await this.listFeeStructures(user)).find((item) => item.id === created.id) ?? created;
    },

    async updateFeeStructure(user: AuthUser, id: string, input: FeeStructureUpdateInput) {
      const [existing] = await db
        .select()
        .from(feeStructures)
        .where(and(eq(feeStructures.schoolId, user.schoolId), eq(feeStructures.id, id)))
        .limit(1);
      if (!existing) throw new ApiError(404, 'Fee structure not found');

      const [updated] = await db
        .update(feeStructures)
        .set({
          ...input,
          description: input.description === undefined ? existing.description : input.description ?? null,
          dueDate: input.dueDate === undefined ? existing.dueDate : input.dueDate ?? null,
          updatedAt: new Date(),
        })
        .where(and(eq(feeStructures.schoolId, user.schoolId), eq(feeStructures.id, id)))
        .returning({ id: feeStructures.id });
      if (!updated) throw new ApiError(500, 'Unable to update fee structure');

      return (await this.listFeeStructures(user)).find((item) => item.id === updated.id) ?? updated;
    },

    async deleteFeeStructure(user: AuthUser, id: string) {
      const [deleted] = await db
        .delete(feeStructures)
        .where(and(eq(feeStructures.schoolId, user.schoolId), eq(feeStructures.id, id)))
        .returning({ id: feeStructures.id });
      if (!deleted) throw new ApiError(404, 'Fee structure not found');
      return deleted;
    },

    async listFeeAllocations(user: AuthUser, filters: FeeAllocationFilters = {}) {
      const conditions = [eq(studentFeeAllocations.schoolId, user.schoolId)];
      if (filters.studentId) conditions.push(eq(studentFeeAllocations.studentId, filters.studentId));
      if (filters.academicYearId) conditions.push(eq(studentFeeAllocations.academicYearId, filters.academicYearId));
      if (filters.status) conditions.push(eq(studentFeeAllocations.status, filters.status));

      const rows = await db
        .select({
          allocation: studentFeeAllocations,
          student: students,
          structure: feeStructures,
          academicYearName: academicYears.name,
        })
        .from(studentFeeAllocations)
        .innerJoin(students, eq(studentFeeAllocations.studentId, students.id))
        .innerJoin(feeStructures, eq(studentFeeAllocations.feeStructureId, feeStructures.id))
        .innerJoin(academicYears, eq(studentFeeAllocations.academicYearId, academicYears.id))
        .where(and(...conditions))
        .orderBy(desc(studentFeeAllocations.dueDate), desc(studentFeeAllocations.createdAt))
        .limit(500);

      const studentIds = Array.from(new Set(rows.map((r) => r.allocation.studentId)));
      const enrollmentsMap = new Map<string, { className: string; sectionName: string; rollNumber: string | null; classId: string; sectionId: string }>();

      if (studentIds.length > 0) {
        const enrollments = await db
          .select({
            studentId: studentEnrollments.studentId,
            className: classes.name,
            sectionName: sections.name,
            rollNumber: studentEnrollments.rollNumber,
            classId: classes.id,
            sectionId: sections.id,
          })
          .from(studentEnrollments)
          .innerJoin(classes, eq(studentEnrollments.classId, classes.id))
          .innerJoin(sections, eq(studentEnrollments.sectionId, sections.id))
          .where(
            eq(studentEnrollments.schoolId, user.schoolId),
          );


        for (const e of enrollments) {
          enrollmentsMap.set(e.studentId, e);
        }
      }

      const allocationIds = rows.map((r) => r.allocation.id);
      const paidMap = new Map<string, number>();
      if (allocationIds.length > 0) {
        const payments = await db
          .select({
            allocationId: feePayments.allocationId,
            amountPaid: feePayments.amountPaid,
          })
          .from(feePayments)
          .where(eq(feePayments.schoolId, user.schoolId));

        for (const p of payments) {
          paidMap.set(p.allocationId, (paidMap.get(p.allocationId) ?? 0) + p.amountPaid);
        }
      }

      const today = new Date().toISOString().slice(0, 10);

      let result = rows.map((r) => {
        const enrollment = enrollmentsMap.get(r.allocation.studentId);
        const totalPaid = paidMap.get(r.allocation.id) ?? 0;
        const balance = Math.max(0, r.allocation.amount - totalPaid);
        let status = r.allocation.status;

        if (totalPaid >= r.allocation.amount) {
          status = 'paid';
        } else if (totalPaid > 0) {
          status = 'partial';
        } else if (r.allocation.dueDate < today) {
          status = 'overdue';
        } else {
          status = 'pending';
        }

        return {
          id: r.allocation.id,
          studentId: r.allocation.studentId,
          feeStructureId: r.allocation.feeStructureId,
          academicYearId: r.allocation.academicYearId,
          amount: r.allocation.amount,
          paidAmount: totalPaid,
          balanceAmount: balance,
          dueDate: r.allocation.dueDate,
          status,
          createdAt: r.allocation.createdAt,
          updatedAt: r.allocation.updatedAt,
          studentName: r.student.fullName,
          admissionNumber: r.student.admissionNumber,
          feeStructureName: r.structure.name,
          feeStructureCode: r.structure.code,
          frequency: r.structure.frequency,
          academicYearName: r.academicYearName,
          className: enrollment?.className ?? 'Unassigned',
          sectionName: enrollment?.sectionName ?? '',
          classId: enrollment?.classId,
          sectionId: enrollment?.sectionId,
          rollNumber: enrollment?.rollNumber ?? null,
        };
      });

      if (filters.classId) {
        result = result.filter((item) => item.classId === filters.classId);
      }
      if (filters.sectionId) {
        result = result.filter((item) => item.sectionId === filters.sectionId);
      }

      return result;
    },

    async createFeeAllocation(user: AuthUser, input: FeeAllocationInput) {
      const [student] = await db
        .select()
        .from(students)
        .where(and(eq(students.schoolId, user.schoolId), eq(students.id, input.studentId)))
        .limit(1);
      if (!student) throw new ApiError(404, 'Student not found');

      const [structure] = await db
        .select()
        .from(feeStructures)
        .where(and(eq(feeStructures.schoolId, user.schoolId), eq(feeStructures.id, input.feeStructureId)))
        .limit(1);
      if (!structure) throw new ApiError(404, 'Fee structure not found');

      const billedAmount = input.amount ?? structure.amount;
      const today = new Date().toISOString().slice(0, 10);
      const initialStatus = input.dueDate < today ? 'overdue' : 'pending';

      const [created] = await db
        .insert(studentFeeAllocations)
        .values({
          schoolId: user.schoolId,
          studentId: input.studentId,
          feeStructureId: input.feeStructureId,
          academicYearId: input.academicYearId,
          amount: billedAmount,
          dueDate: input.dueDate,
          status: initialStatus,
        })
        .returning({ id: studentFeeAllocations.id });

      if (!created) throw new ApiError(500, 'Unable to create fee allocation');

      return (await this.listFeeAllocations(user, { studentId: input.studentId })).find((a) => a.id === created.id) ?? created;
    },

    async recordFeePayment(user: AuthUser, input: FeePaymentInput) {
      const [allocation] = await db
        .select()
        .from(studentFeeAllocations)
        .where(and(eq(studentFeeAllocations.schoolId, user.schoolId), eq(studentFeeAllocations.id, input.allocationId)))
        .limit(1);
      if (!allocation) throw new ApiError(404, 'Fee allocation not found');

      const datePrefix = new Date().toISOString().slice(0, 10).replace(/-/g, '');
      const randomSuffix = Math.floor(1000 + Math.random() * 9000).toString();
      const receiptNumber = `REC-${datePrefix}-${randomSuffix}`;

      const [payment] = await db
        .insert(feePayments)
        .values({
          schoolId: user.schoolId,
          allocationId: input.allocationId,
          studentId: allocation.studentId,
          receiptNumber,
          amountPaid: input.amountPaid,
          paymentMethod: input.paymentMethod,
          transactionReference: input.transactionReference ?? null,
          notes: input.notes ?? null,
          paidAt: input.paidAt ? new Date(input.paidAt) : new Date(),
          recordedByStaffId: user.staffId ?? null,
        })
        .returning();

      if (!payment) throw new ApiError(500, 'Unable to record payment');

      const existingPayments = await db
        .select({ amountPaid: feePayments.amountPaid })
        .from(feePayments)
        .where(eq(feePayments.allocationId, allocation.id));

      const totalPaid = existingPayments.reduce((sum, p) => sum + p.amountPaid, 0);
      const newStatus = totalPaid >= allocation.amount ? 'paid' : totalPaid > 0 ? 'partial' : 'pending';

      await db
        .update(studentFeeAllocations)
        .set({ status: newStatus, updatedAt: new Date() })
        .where(eq(studentFeeAllocations.id, allocation.id));

      return {
        ...payment,
        allocationAmount: allocation.amount,
        totalPaid,
        remainingBalance: Math.max(0, allocation.amount - totalPaid),
      };
    },

    async listFeePayments(user: AuthUser, filters: FeePaymentFilters = {}) {
      const conditions = [eq(feePayments.schoolId, user.schoolId)];
      if (filters.studentId) conditions.push(eq(feePayments.studentId, filters.studentId));
      if (filters.allocationId) conditions.push(eq(feePayments.allocationId, filters.allocationId));

      const rows = await db
        .select({
          payment: feePayments,
          student: students,
          structureName: feeStructures.name,
          structureCode: feeStructures.code,
          staffName: staff.fullName,
        })
        .from(feePayments)
        .innerJoin(students, eq(feePayments.studentId, students.id))
        .innerJoin(studentFeeAllocations, eq(feePayments.allocationId, studentFeeAllocations.id))
        .innerJoin(feeStructures, eq(studentFeeAllocations.feeStructureId, feeStructures.id))
        .leftJoin(staff, eq(feePayments.recordedByStaffId, staff.id))
        .where(and(...conditions))
        .orderBy(desc(feePayments.paidAt))
        .limit(300);

      return rows.map((r) => ({
        ...r.payment,
        studentName: r.student.fullName,
        admissionNumber: r.student.admissionNumber,
        feeStructureName: r.structureName,
        feeStructureCode: r.structureCode,
        recordedByStaffName: r.staffName ?? 'Administrator',
      }));
    },

    async portalFeeSummary(user: AuthUser, studentId?: string) {
      const allowed = await portalStudentsFor(db, user);
      if (allowed.length === 0) throw new ApiError(403, 'No students linked to this account');

      const portalStudent = studentId ? allowed.find((item) => item.id === studentId) : allowed[0];
      if (!portalStudent) throw new ApiError(403, 'Unauthorized student request');

      const allocations = await this.listFeeAllocations(user, { studentId: portalStudent.id });
      const payments = await this.listFeePayments(user, { studentId: portalStudent.id });

      let totalBilled = 0;
      let totalPaid = 0;

      for (const a of allocations) {
        totalBilled += a.amount;
        totalPaid += a.paidAmount;
      }

      const balanceDue = Math.max(0, totalBilled - totalPaid);

      return {
        student: portalStudent,
        summary: {
          totalBilled,
          totalPaid,
          balanceDue,
          allocationCount: allocations.length,
          paymentCount: payments.length,
        },
        allocations,
        payments,
      };
    },

    async createPaymentOrder(
      user: AuthUser,
      input: { allocationId: string; amount: number; returnUrl?: string | undefined },
      env: Env,
    ) {
      const [alloc] = await db
        .select({
          id: studentFeeAllocations.id,
          schoolId: studentFeeAllocations.schoolId,
          studentId: studentFeeAllocations.studentId,
          totalAmount: studentFeeAllocations.amount,
          status: studentFeeAllocations.status,
          studentName: students.fullName,
          feeName: feeStructures.name,
          admissionNumber: students.admissionNumber,
        })
        .from(studentFeeAllocations)
        .innerJoin(students, eq(students.id, studentFeeAllocations.studentId))
        .innerJoin(feeStructures, eq(feeStructures.id, studentFeeAllocations.feeStructureId))
        .where(
          and(
            eq(studentFeeAllocations.id, input.allocationId),
            eq(studentFeeAllocations.schoolId, user.schoolId),
          ),
        )
        .limit(1);

      if (!alloc) throw new ApiError(404, 'Fee allocation not found');

      if (!user.roles.includes('admin')) {
        const allowed = await portalStudentsFor(db, user);
        if (!allowed.some((s) => s.id === alloc.studentId)) {
          throw new ApiError(403, 'Unauthorized access to student fee allocation');
        }
      }

      const existingPayments = await db
        .select({
          amountPaid: feePayments.amountPaid,
        })
        .from(feePayments)
        .where(
          and(
            eq(feePayments.allocationId, alloc.id),
            eq(feePayments.schoolId, user.schoolId),
          ),
        );

      const totalPaid = existingPayments.reduce((sum, p) => sum + p.amountPaid, 0);
      const balanceDue = Math.max(0, alloc.totalAmount - totalPaid);

      if (balanceDue <= 0) {
        throw new ApiError(400, 'Fee allocation is already fully settled');
      }

      if (input.amount > balanceDue) {
        throw new ApiError(400, `Amount exceeds outstanding balance of ₹${balanceDue}`);
      }

      if (input.amount <= 0) {
        throw new ApiError(400, 'Payment amount must be greater than zero');
      }

      const orderId = `SCH_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`.toUpperCase();

      const cashfree = new CashfreeClient(env);
      const cfOrder = await cashfree.createOrder({
        orderId,
        orderAmount: input.amount,
        customerId: alloc.studentId,
        customerName: alloc.studentName,
        customerEmail: user.email,
        customerPhone: '9999999999',
        orderNote: `${alloc.feeName} for ${alloc.studentName} (${alloc.admissionNumber || ''})`,
        returnUrl: input.returnUrl,
      });

      const [orderRecord] = await db
        .insert(paymentOrders)
        .values({
          schoolId: user.schoolId,
          studentId: alloc.studentId,
          allocationId: alloc.id,
          gateway: 'cashfree',
          gatewayOrderId: orderId,
          paymentSessionId: cfOrder.paymentSessionId,
          amount: input.amount,
          currency: 'INR',
          status: 'ACTIVE',
        })
        .returning();

      if (!orderRecord) {
        throw new ApiError(500, 'Failed to persist payment order record');
      }

      return {
        orderId: orderRecord.gatewayOrderId,
        paymentSessionId: orderRecord.paymentSessionId,
        amount: orderRecord.amount,
        currency: orderRecord.currency,
        studentName: alloc.studentName,
        feeName: alloc.feeName,
        isSimulated: cfOrder.isSimulated,
      };
    },

    async verifyPaymentOrder(user: AuthUser, orderId: string, env: Env) {
      const [order] = await db
        .select()
        .from(paymentOrders)
        .where(
          and(
            eq(paymentOrders.gatewayOrderId, orderId),
            eq(paymentOrders.schoolId, user.schoolId),
          ),
        )
        .limit(1);

      if (!order) throw new ApiError(404, 'Payment order not found');

      if (order.status === 'PAID') {
        const [existingPayment] = await db
          .select()
          .from(feePayments)
          .where(
            and(
              eq(feePayments.allocationId, order.allocationId),
              eq(feePayments.transactionReference, order.gatewayOrderId),
            ),
          )
          .limit(1);

        return {
          success: true,
          status: 'PAID',
          receiptNumber: existingPayment?.receiptNumber ?? 'REC-PAID',
          amountPaid: order.amount,
        };
      }

      const cashfree = new CashfreeClient(env);
      let payments = await cashfree.getPayments(orderId);
      let successPayment = payments.find((p) => p.paymentStatus === 'SUCCESS');

      // In Sandbox mode, if client verifies and no payment transaction has settled yet on Cashfree sandbox,
      // simulate settlement via Cashfree's test UPI channel
      if (!successPayment && (env.CASHFREE_ENV === 'sandbox' || env.CASHFREE_APP_ID?.startsWith('TEST'))) {
        await cashfree.payOrderSession(order.paymentSessionId);
        payments = await cashfree.getPayments(orderId);
        successPayment = payments.find((p) => p.paymentStatus === 'SUCCESS');
      }

      if (!successPayment) {
        return {
          success: false,
          status: order.status,
          message: 'Payment has not been completed or was not approved by bank.',
        };
      }

      const year = new Date().getFullYear();
      const countRes = await db
        .select({ count: sql<number>`count(*)::int` })
        .from(feePayments)
        .where(eq(feePayments.schoolId, user.schoolId));
      const nextSeq = (countRes[0]?.count ?? 0) + 1;
      const receiptNumber = `REC-${year}-${String(nextSeq).padStart(5, '0')}`;

      await db
        .update(paymentOrders)
        .set({
          status: 'PAID',
          cfPaymentId: successPayment.cfPaymentId,
          paymentMethod: successPayment.paymentMethod,
          updatedAt: new Date(),
        })
        .where(eq(paymentOrders.id, order.id));

      let method: 'cash' | 'upi' | 'card' | 'bank_transfer' | 'cheque' = 'upi';
      const mStr = (successPayment.paymentMethod || '').toLowerCase();
      if (mStr.includes('card')) method = 'card';
      else if (mStr.includes('netbanking') || mStr.includes('bank')) method = 'bank_transfer';
      else method = 'upi';

      const [payment] = await db
        .insert(feePayments)
        .values({
          schoolId: user.schoolId,
          allocationId: order.allocationId,
          studentId: order.studentId,
          receiptNumber,
          amountPaid: order.amount,
          paymentMethod: method,
          transactionReference: order.gatewayOrderId,
          paidAt: new Date(successPayment.paymentTime || Date.now()),
          notes: `Online payment via Cashfree (${successPayment.cfPaymentId})`,
        })
        .returning();

      if (!payment) {
        throw new ApiError(500, 'Failed to persist fee payment record');
      }

      const [alloc] = await db
        .select()
        .from(studentFeeAllocations)
        .where(eq(studentFeeAllocations.id, order.allocationId))
        .limit(1);

      if (alloc) {
        const allPayments = await db
          .select({ amount: feePayments.amountPaid })
          .from(feePayments)
          .where(eq(feePayments.allocationId, alloc.id));
        const totalPaid = allPayments.reduce((sum, p) => sum + p.amount, 0);
        const newStatus = totalPaid >= alloc.amount ? 'paid' : (totalPaid > 0 ? 'partial' : 'pending');

        await db
          .update(studentFeeAllocations)
          .set({ status: newStatus, updatedAt: new Date() })
          .where(eq(studentFeeAllocations.id, alloc.id));
      }

      return {
        success: true,
        status: 'PAID',
        receiptNumber: payment.receiptNumber,
        amountPaid: payment.amountPaid,
        paidAt: payment.paidAt,
        paymentMethod: payment.paymentMethod,
      };
    },

    async handleCashfreeWebhook(payload: Record<string, unknown>, env: Env) {
      const data = payload.data as Record<string, unknown> | undefined;
      const order = data?.order as Record<string, unknown> | undefined;
      const payment = data?.payment as Record<string, unknown> | undefined;

      const orderId = (order?.order_id as string) || (payload.order_id as string);
      const cfPaymentId = (payment?.cf_payment_id ? String(payment.cf_payment_id) : undefined) ||
        (payload.cf_payment_id ? String(payload.cf_payment_id) : undefined);
      const paymentStatus = (payment?.payment_status as string) || (payload.txStatus as string);

      if (!orderId) {
        return { handled: false, reason: 'No order_id in webhook payload' };
      }

      const eventId = cfPaymentId ? `${orderId}_${cfPaymentId}` : `${orderId}_${Date.now()}`;

      // Idempotency check
      const [existingEvent] = await db
        .select({ id: paymentWebhookEvents.id })
        .from(paymentWebhookEvents)
        .where(eq(paymentWebhookEvents.eventId, eventId))
        .limit(1);

      if (existingEvent) {
        return { handled: true, deduplicated: true };
      }

      // Record webhook event
      await db.insert(paymentWebhookEvents).values({
        gateway: 'cashfree',
        eventId,
        eventType: (payload.type as string) || 'PAYMENT_WEBHOOK',
        payload,
      });

      if (paymentStatus === 'SUCCESS') {
        const [ord] = await db
          .select()
          .from(paymentOrders)
          .where(eq(paymentOrders.gatewayOrderId, orderId))
          .limit(1);

        if (ord && ord.status !== 'PAID') {
          const year = new Date().getFullYear();
          const countRes = await db
            .select({ count: sql<number>`count(*)::int` })
            .from(feePayments)
            .where(eq(feePayments.schoolId, ord.schoolId));
          const nextSeq = (countRes[0]?.count ?? 0) + 1;
          const receiptNumber = `REC-${year}-${String(nextSeq).padStart(5, '0')}`;

          await db
            .update(paymentOrders)
            .set({
              status: 'PAID',
              cfPaymentId: cfPaymentId || 'WEBHOOK',
              paymentMethod: 'upi',
              updatedAt: new Date(),
            })
            .where(eq(paymentOrders.id, ord.id));

          await db.insert(feePayments).values({
            schoolId: ord.schoolId,
            allocationId: ord.allocationId,
            studentId: ord.studentId,
            receiptNumber,
            amountPaid: ord.amount,
            paymentMethod: 'upi',
            transactionReference: ord.gatewayOrderId,
            paidAt: new Date(),
            notes: `Online payment reconciled via Cashfree Webhook (${cfPaymentId || ''})`,
          });

          const [alloc] = await db
            .select()
            .from(studentFeeAllocations)
            .where(eq(studentFeeAllocations.id, ord.allocationId))
            .limit(1);

          if (alloc) {
            const allPayments = await db
              .select({ amount: feePayments.amountPaid })
              .from(feePayments)
              .where(eq(feePayments.allocationId, alloc.id));
            const totalPaid = allPayments.reduce((sum, p) => sum + p.amount, 0);
            const newStatus = totalPaid >= alloc.amount ? 'paid' : (totalPaid > 0 ? 'partial' : 'pending');

            await db
              .update(studentFeeAllocations)
              .set({ status: newStatus, updatedAt: new Date() })
              .where(eq(studentFeeAllocations.id, alloc.id));
          }
        }
      }

      return { handled: true };
    },


    async admissionSummary(user: AuthUser, academicYearId?: string) {
      const yearConditions = [eq(academicYears.schoolId, user.schoolId)];
      if (academicYearId) {
        yearConditions.push(eq(academicYears.id, academicYearId));
      } else {
        yearConditions.push(eq(academicYears.isActive, true));
      }
      const [targetYear] = await db
        .select({ id: academicYears.id, name: academicYears.name })
        .from(academicYears)
        .where(and(...yearConditions))
        .limit(1);

      const appConditions = [eq(admissionApplications.schoolId, user.schoolId)];
      if (targetYear) {
        appConditions.push(eq(admissionApplications.academicYearId, targetYear.id));
      } else if (academicYearId) {
        appConditions.push(eq(admissionApplications.academicYearId, academicYearId));
      }

      const allApps = await db
        .select()
        .from(admissionApplications)
        .where(and(...appConditions))
        .limit(1000);

      const byStatus = {
        inquiry: 0,
        applied: 0,
        under_review: 0,
        approved: 0,
        enrolled: 0,
        rejected: 0,
      };

      for (const app of allApps) {
        if (app.status in byStatus) {
          byStatus[app.status as keyof typeof byStatus]++;
        }
      }

      const totalApplications = allApps.length;
      const enrolledCount = byStatus.enrolled;
      const actionableCount = allApps.filter((a) => a.status !== 'inquiry').length;
      const conversionRate = actionableCount > 0 ? Math.round((enrolledCount / actionableCount) * 1000) / 10 : 0;

      const schoolClasses = await db
        .select({ id: classes.id, name: classes.name })
        .from(classes)
        .where(eq(classes.schoolId, user.schoolId))
        .orderBy(classes.name);

      const enrollmentsConditions = [eq(studentEnrollments.schoolId, user.schoolId)];
      if (targetYear) {
        enrollmentsConditions.push(eq(studentEnrollments.academicYearId, targetYear.id));
      }
      const enrollments = await db
        .select({ classId: studentEnrollments.classId })
        .from(studentEnrollments)
        .where(and(...enrollmentsConditions));

      const enrolledMap = new Map<string, number>();
      for (const e of enrollments) {
        enrolledMap.set(e.classId, (enrolledMap.get(e.classId) ?? 0) + 1);
      }

      const classBreakdown = schoolClasses.map((cls) => {
        const appsForClass = allApps.filter((a) => a.applyingForClassId === cls.id);
        const enrolledInClass = enrolledMap.get(cls.id) ?? 0;
        const capacity = 40;
        const availableSeats = Math.max(0, capacity - enrolledInClass);
        return {
          classId: cls.id,
          className: cls.name,
          capacity,
          enrolledCount: enrolledInClass,
          availableSeats,
          applicationsCount: appsForClass.length,
          pendingCount: appsForClass.filter((a) => a.status === 'applied' || a.status === 'under_review').length,
          approvedCount: appsForClass.filter((a) => a.status === 'approved').length,
          enrolledFromAdmissions: appsForClass.filter((a) => a.status === 'enrolled').length,
        };
      });

      return {
        academicYear: targetYear ?? null,
        totalApplications,
        byStatus,
        conversionRate,
        classBreakdown,
      };
    },

    async listAdmissionApplications(user: AuthUser, filters: AdmissionQueryFilters = {}) {
      const conditions = [eq(admissionApplications.schoolId, user.schoolId)];
      if (filters.academicYearId) {
        conditions.push(eq(admissionApplications.academicYearId, filters.academicYearId));
      }
      if (filters.classId) {
        conditions.push(eq(admissionApplications.applyingForClassId, filters.classId));
      }
      if (filters.status) {
        conditions.push(eq(admissionApplications.status, filters.status));
      }

      const rows = await db
        .select({
          app: admissionApplications,
          className: classes.name,
          yearName: academicYears.name,
          enrolledStudentAdmissionNumber: students.admissionNumber,
          enrolledStudentName: students.fullName,
        })
        .from(admissionApplications)
        .innerJoin(classes, eq(admissionApplications.applyingForClassId, classes.id))
        .innerJoin(academicYears, eq(admissionApplications.academicYearId, academicYears.id))
        .leftJoin(students, eq(admissionApplications.enrolledStudentId, students.id))
        .where(and(...conditions))
        .orderBy(desc(admissionApplications.applicationDate), desc(admissionApplications.createdAt))
        .limit(300);

      const docRows = await db
        .select({
          applicationId: admissionDocuments.applicationId,
          status: admissionDocuments.status,
        })
        .from(admissionDocuments)
        .where(eq(admissionDocuments.schoolId, user.schoolId));

      const docStatsMap = new Map<string, { totalDocuments: number; verifiedDocuments: number }>();
      for (const doc of docRows) {
        const stats = docStatsMap.get(doc.applicationId) ?? { totalDocuments: 0, verifiedDocuments: 0 };
        stats.totalDocuments++;
        if (doc.status === 'verified') stats.verifiedDocuments++;
        docStatsMap.set(doc.applicationId, stats);
      }

      let results = rows.map((r) => {
        const stats = docStatsMap.get(r.app.id) ?? { totalDocuments: 0, verifiedDocuments: 0 };
        return {
          ...r.app,
          className: r.className,
          academicYearName: r.yearName,
          enrolledStudentAdmissionNumber: r.enrolledStudentAdmissionNumber ?? null,
          enrolledStudentName: r.enrolledStudentName ?? null,
          totalDocuments: stats.totalDocuments,
          verifiedDocuments: stats.verifiedDocuments,
        };
      });

      if (filters.search) {
        const s = filters.search.toLowerCase();
        results = results.filter(
          (a) =>
            a.applicantName.toLowerCase().includes(s) ||
            a.parentName.toLowerCase().includes(s) ||
            a.parentPhone.toLowerCase().includes(s) ||
            a.applicationNumber.toLowerCase().includes(s) ||
            (a.previousSchool && a.previousSchool.toLowerCase().includes(s)),
        );
      }

      return results;
    },

    async getAdmissionApplication(user: AuthUser, id: string) {
      const [appRow] = await db
        .select({
          app: admissionApplications,
          className: classes.name,
          yearName: academicYears.name,
          enrolledStudentAdmissionNumber: students.admissionNumber,
          enrolledStudentName: students.fullName,
        })
        .from(admissionApplications)
        .innerJoin(classes, eq(admissionApplications.applyingForClassId, classes.id))
        .innerJoin(academicYears, eq(admissionApplications.academicYearId, academicYears.id))
        .leftJoin(students, eq(admissionApplications.enrolledStudentId, students.id))
        .where(and(eq(admissionApplications.schoolId, user.schoolId), eq(admissionApplications.id, id)))
        .limit(1);

      if (!appRow) throw new ApiError(404, 'Admission application not found');

      const docs = await db
        .select({
          doc: admissionDocuments,
          verifiedByStaffName: staff.fullName,
        })
        .from(admissionDocuments)
        .leftJoin(staff, eq(admissionDocuments.verifiedByStaffId, staff.id))
        .where(and(eq(admissionDocuments.schoolId, user.schoolId), eq(admissionDocuments.applicationId, id)))
        .orderBy(admissionDocuments.createdAt);

      const documents = docs.map((d) => ({
        ...d.doc,
        verifiedByStaffName: d.verifiedByStaffName ?? null,
      }));

      return {
        ...appRow.app,
        className: appRow.className,
        academicYearName: appRow.yearName,
        enrolledStudentAdmissionNumber: appRow.enrolledStudentAdmissionNumber ?? null,
        enrolledStudentName: appRow.enrolledStudentName ?? null,
        documents,
      };
    },

    async createAdmissionApplication(user: AuthUser, input: AdmissionApplicationInput) {
      const [targetClass] = await db
        .select({ id: classes.id })
        .from(classes)
        .where(and(eq(classes.schoolId, user.schoolId), eq(classes.id, input.applyingForClassId)))
        .limit(1);
      if (!targetClass) throw new ApiError(422, 'Selected class is not available');

      const [targetYear] = await db
        .select({ id: academicYears.id })
        .from(academicYears)
        .where(and(eq(academicYears.schoolId, user.schoolId), eq(academicYears.id, input.academicYearId)))
        .limit(1);
      if (!targetYear) throw new ApiError(422, 'Selected academic year is not available');

      const currentYear = new Date().getFullYear();
      const randomSuffix = Math.floor(1000 + Math.random() * 9000);
      const appNumber = `APP-${currentYear}-${randomSuffix}`;
      const applicationDate = input.applicationDate ?? new Date().toISOString().slice(0, 10);

      const [created] = await db
        .insert(admissionApplications)
        .values({
          schoolId: user.schoolId,
          academicYearId: input.academicYearId,
          applyingForClassId: input.applyingForClassId,
          applicationNumber: appNumber,
          applicantName: input.applicantName,
          dateOfBirth: input.dateOfBirth ?? null,
          gender: input.gender ?? null,
          parentName: input.parentName,
          parentEmail: input.parentEmail ?? null,
          parentPhone: input.parentPhone,
          address: input.address ?? null,
          previousSchool: input.previousSchool ?? null,
          status: input.status,
          applicationDate,
          notes: input.notes ?? null,
        })
        .returning();

      if (!created) throw new ApiError(500, 'Unable to create admission application');

      const docTemplates =
        input.documents && input.documents.length > 0
          ? input.documents
          : [
              { title: 'Birth Certificate', status: 'pending' as const },
              { title: 'Transfer Certificate / Previous Report', status: 'pending' as const },
              { title: 'Address Proof / Parent Identity Card', status: 'pending' as const },
              { title: 'Recent Passport Photograph', status: 'pending' as const },
            ];

      for (const doc of docTemplates) {
        await db.insert(admissionDocuments).values({
          schoolId: user.schoolId,
          applicationId: created.id,
          title: doc.title,
          status: doc.status,
          documentNumber: doc.documentNumber ?? null,
          notes: doc.notes ?? null,
        });
      }

      return this.getAdmissionApplication(user, created.id);
    },

    async updateAdmissionApplication(user: AuthUser, id: string, input: AdmissionApplicationUpdateInput) {
      const [existing] = await db
        .select()
        .from(admissionApplications)
        .where(and(eq(admissionApplications.schoolId, user.schoolId), eq(admissionApplications.id, id)))
        .limit(1);

      if (!existing) throw new ApiError(404, 'Admission application not found');

      if (input.applyingForClassId && input.applyingForClassId !== existing.applyingForClassId) {
        const [targetClass] = await db
          .select({ id: classes.id })
          .from(classes)
          .where(and(eq(classes.schoolId, user.schoolId), eq(classes.id, input.applyingForClassId)))
          .limit(1);
        if (!targetClass) throw new ApiError(422, 'Selected class is not available');
      }

      let decisionDate = input.decisionDate !== undefined ? input.decisionDate : existing.decisionDate;
      if (!decisionDate && input.status && (input.status === 'approved' || input.status === 'rejected')) {
        decisionDate = new Date().toISOString().slice(0, 10);
      }

      const [updated] = await db
        .update(admissionApplications)
        .set({
          academicYearId: input.academicYearId ?? existing.academicYearId,
          applyingForClassId: input.applyingForClassId ?? existing.applyingForClassId,
          applicantName: input.applicantName ?? existing.applicantName,
          dateOfBirth: input.dateOfBirth !== undefined ? input.dateOfBirth : existing.dateOfBirth,
          gender: input.gender !== undefined ? input.gender : existing.gender,
          parentName: input.parentName ?? existing.parentName,
          parentEmail: input.parentEmail !== undefined ? input.parentEmail : existing.parentEmail,
          parentPhone: input.parentPhone ?? existing.parentPhone,
          address: input.address !== undefined ? input.address : existing.address,
          previousSchool: input.previousSchool !== undefined ? input.previousSchool : existing.previousSchool,
          status: input.status ?? existing.status,
          applicationDate: input.applicationDate ?? existing.applicationDate,
          decisionDate,
          notes: input.notes !== undefined ? input.notes : existing.notes,
          updatedAt: new Date(),
        })
        .where(eq(admissionApplications.id, id))
        .returning();

      if (!updated) throw new ApiError(500, 'Unable to update admission application');

      return this.getAdmissionApplication(user, id);
    },

    async deleteAdmissionApplication(user: AuthUser, id: string) {
      const [existing] = await db
        .select({ id: admissionApplications.id })
        .from(admissionApplications)
        .where(and(eq(admissionApplications.schoolId, user.schoolId), eq(admissionApplications.id, id)))
        .limit(1);

      if (!existing) throw new ApiError(404, 'Admission application not found');

      await db.delete(admissionDocuments).where(eq(admissionDocuments.applicationId, id));
      await db.delete(admissionApplications).where(eq(admissionApplications.id, id));

      return { success: true, id };
    },

    async enrollApplicant(user: AuthUser, id: string, input: EnrollApplicantInput) {
      const [app] = await db
        .select()
        .from(admissionApplications)
        .where(and(eq(admissionApplications.schoolId, user.schoolId), eq(admissionApplications.id, id)))
        .limit(1);

      if (!app) throw new ApiError(404, 'Admission application not found');

      if (app.status === 'enrolled' || app.enrolledStudentId) {
        throw new ApiError(409, 'Applicant is already enrolled');
      }

      const [targetSection] = await db
        .select()
        .from(sections)
        .where(
          and(
            eq(sections.schoolId, user.schoolId),
            eq(sections.id, input.sectionId),
            eq(sections.classId, app.applyingForClassId),
          ),
        )
        .limit(1);

      if (!targetSection) {
        throw new ApiError(422, 'Selected section does not belong to the target class');
      }

      const admissionNumber =
        input.admissionNumber ||
        `ADM-${new Date().getFullYear()}-${Math.floor(1000 + Math.random() * 9000)}`;

      const [student] = await db
        .insert(students)
        .values({
          schoolId: user.schoolId,
          admissionNumber,
          fullName: app.applicantName,
          guardianName: app.parentName,
          guardianPhone: app.parentPhone,
          isActive: true,
        })
        .returning();

      if (!student) throw new ApiError(500, 'Unable to create student profile');

      await db.insert(studentEnrollments).values({
        schoolId: user.schoolId,
        studentId: student.id,
        academicYearId: app.academicYearId,
        classId: app.applyingForClassId,
        sectionId: input.sectionId,
        rollNumber: input.rollNumber ?? null,
      });

      const [updatedApp] = await db
        .update(admissionApplications)
        .set({
          status: 'enrolled',
          enrolledStudentId: student.id,
          decisionDate: new Date().toISOString().slice(0, 10),
          updatedAt: new Date(),
        })
        .where(eq(admissionApplications.id, id))
        .returning();

      return {
        application: updatedApp,
        student,
      };
    },

    async listAdmissionDocuments(user: AuthUser, applicationId: string) {
      const [app] = await db
        .select({ id: admissionApplications.id })
        .from(admissionApplications)
        .where(and(eq(admissionApplications.schoolId, user.schoolId), eq(admissionApplications.id, applicationId)))
        .limit(1);
      if (!app) throw new ApiError(404, 'Admission application not found');

      const docs = await db
        .select({
          doc: admissionDocuments,
          verifiedByStaffName: staff.fullName,
        })
        .from(admissionDocuments)
        .leftJoin(staff, eq(admissionDocuments.verifiedByStaffId, staff.id))
        .where(and(eq(admissionDocuments.schoolId, user.schoolId), eq(admissionDocuments.applicationId, applicationId)))
        .orderBy(admissionDocuments.createdAt);

      return docs.map((d) => ({
        ...d.doc,
        verifiedByStaffName: d.verifiedByStaffName ?? null,
      }));
    },

    async addAdmissionDocument(user: AuthUser, applicationId: string, input: AddAdmissionDocumentInput) {
      const [app] = await db
        .select({ id: admissionApplications.id })
        .from(admissionApplications)
        .where(and(eq(admissionApplications.schoolId, user.schoolId), eq(admissionApplications.id, applicationId)))
        .limit(1);
      if (!app) throw new ApiError(404, 'Admission application not found');

      const [doc] = await db
        .insert(admissionDocuments)
        .values({
          schoolId: user.schoolId,
          applicationId,
          title: input.title,
          status: input.status,
          documentNumber: input.documentNumber ?? null,
          fileKey: input.fileKey ?? null,
          fileUrl: input.fileUrl ?? null,
          fileName: input.fileName ?? null,
          fileSize: input.fileSize ?? null,
          mimeType: input.mimeType ?? null,
          verifiedByStaffId: input.status === 'verified' ? (user.staffId ?? null) : null,
          notes: input.notes ?? null,
        })
        .returning();

      if (!doc) throw new ApiError(500, 'Unable to add admission document');
      return doc;
    },

    async updateAdmissionDocument(user: AuthUser, documentId: string, input: UpdateAdmissionDocumentInput) {
      const [existing] = await db
        .select()
        .from(admissionDocuments)
        .where(and(eq(admissionDocuments.schoolId, user.schoolId), eq(admissionDocuments.id, documentId)))
        .limit(1);

      if (!existing) throw new ApiError(404, 'Admission document not found');

      const verifiedByStaffId =
        input.status === 'verified'
          ? (user.staffId ?? existing.verifiedByStaffId)
          : input.status
            ? null
            : existing.verifiedByStaffId;

      const [updated] = await db
        .update(admissionDocuments)
        .set({
          title: input.title ?? existing.title,
          status: input.status ?? existing.status,
          documentNumber: input.documentNumber !== undefined ? input.documentNumber : existing.documentNumber,
          fileKey: input.fileKey !== undefined ? input.fileKey : existing.fileKey,
          fileUrl: input.fileUrl !== undefined ? input.fileUrl : existing.fileUrl,
          fileName: input.fileName !== undefined ? input.fileName : existing.fileName,
          fileSize: input.fileSize !== undefined ? input.fileSize : existing.fileSize,
          mimeType: input.mimeType !== undefined ? input.mimeType : existing.mimeType,
          verifiedByStaffId,
          notes: input.notes !== undefined ? input.notes : existing.notes,
          updatedAt: new Date(),
        })
        .where(eq(admissionDocuments.id, documentId))
        .returning();

      if (!updated) throw new ApiError(500, 'Unable to update admission document');
      return updated;
    },

    async getAdmissionDocument(user: AuthUser, documentId: string) {
      const [doc] = await db
        .select({
          doc: admissionDocuments,
          verifiedByStaffName: staff.fullName,
        })
        .from(admissionDocuments)
        .leftJoin(staff, eq(admissionDocuments.verifiedByStaffId, staff.id))
        .where(and(eq(admissionDocuments.schoolId, user.schoolId), eq(admissionDocuments.id, documentId)))
        .limit(1);

      if (!doc) throw new ApiError(404, 'Admission document not found');
      return {
        ...doc.doc,
        verifiedByStaffName: doc.verifiedByStaffName ?? null,
      };
    },

    async attachAdmissionDocumentFile(
      user: AuthUser,
      applicationId: string,
      documentId: string,
      fileData: { fileKey: string; fileUrl: string; fileName: string; fileSize: number; mimeType: string },
    ) {
      const [existing] = await db
        .select()
        .from(admissionDocuments)
        .where(
          and(
            eq(admissionDocuments.schoolId, user.schoolId),
            eq(admissionDocuments.applicationId, applicationId),
            eq(admissionDocuments.id, documentId),
          ),
        )
        .limit(1);

      if (!existing) throw new ApiError(404, 'Admission document not found');

      const nextStatus = existing.status === 'pending' ? 'submitted' : existing.status;

      const [updated] = await db
        .update(admissionDocuments)
        .set({
          fileKey: fileData.fileKey,
          fileUrl: fileData.fileUrl,
          fileName: fileData.fileName,
          fileSize: fileData.fileSize,
          mimeType: fileData.mimeType,
          status: nextStatus,
          updatedAt: new Date(),
        })
        .where(eq(admissionDocuments.id, documentId))
        .returning();

      if (!updated) throw new ApiError(500, 'Unable to attach file to document');
      return updated;
    },

    async removeAdmissionDocumentFile(user: AuthUser, documentId: string) {
      const [existing] = await db
        .select()
        .from(admissionDocuments)
        .where(and(eq(admissionDocuments.schoolId, user.schoolId), eq(admissionDocuments.id, documentId)))
        .limit(1);

      if (!existing) throw new ApiError(404, 'Admission document not found');

      const fileKey = existing.fileKey;

      const [updated] = await db
        .update(admissionDocuments)
        .set({
          fileKey: null,
          fileUrl: null,
          fileName: null,
          fileSize: null,
          mimeType: null,
          status: existing.status === 'submitted' ? 'pending' : existing.status,
          updatedAt: new Date(),
        })
        .where(eq(admissionDocuments.id, documentId))
        .returning();

      return {
        document: updated,
        deletedFileKey: fileKey,
      };
    },

    async deleteAdmissionDocument(user: AuthUser, documentId: string) {
      const [existing] = await db
        .select({ id: admissionDocuments.id, fileKey: admissionDocuments.fileKey })
        .from(admissionDocuments)
        .where(and(eq(admissionDocuments.schoolId, user.schoolId), eq(admissionDocuments.id, documentId)))
        .limit(1);

      if (!existing) throw new ApiError(404, 'Admission document not found');

      await db.delete(admissionDocuments).where(eq(admissionDocuments.id, documentId));
      return { success: true, id: documentId, deletedFileKey: existing.fileKey };
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

    async listTeacherHomeworkSubmissions(user: AuthUser, assignmentId: string) {
      if (!user.staffId) throw new ApiError(403, 'Teacher profile is required');
      const [assignment] = await db
        .select()
        .from(homeworkAssignments)
        .where(
          and(
            eq(homeworkAssignments.schoolId, user.schoolId),
            eq(homeworkAssignments.ownerStaffId, user.staffId),
            eq(homeworkAssignments.id, assignmentId),
          ),
        )
        .limit(1);
      if (!assignment) throw new ApiError(404, 'Homework assignment not found');

      const studentsInSec = await db
        .select({
          studentId: students.id,
          fullName: students.fullName,
          admissionNumber: students.admissionNumber,
          rollNumber: studentEnrollments.rollNumber,
        })
        .from(studentEnrollments)
        .innerJoin(students, eq(studentEnrollments.studentId, students.id))
        .where(
          and(
            eq(studentEnrollments.schoolId, user.schoolId),
            eq(studentEnrollments.academicYearId, assignment.academicYearId),
            eq(studentEnrollments.classId, assignment.classId),
            eq(studentEnrollments.sectionId, assignment.sectionId),
            eq(students.isActive, true),
          ),
        )
        .orderBy(studentEnrollments.rollNumber, students.fullName);

      const submissions = await db
        .select()
        .from(homeworkSubmissions)
        .where(eq(homeworkSubmissions.assignmentId, assignmentId));

      const subMap = new Map(submissions.map((s) => [s.studentId, s]));

      return {
        assignment,
        submissions: studentsInSec.map((st) => ({
          student: st,
          submission: subMap.get(st.studentId) ?? null,
        })),
      };
    },

    async gradeHomeworkSubmission(
      user: AuthUser,
      submissionId: string,
      input: z.infer<typeof gradeHomeworkSubmissionSchema>,
    ) {
      if (!user.staffId) throw new ApiError(403, 'Teacher profile is required');
      const [submission] = await db
        .select()
        .from(homeworkSubmissions)
        .where(eq(homeworkSubmissions.id, submissionId))
        .limit(1);
      if (!submission) throw new ApiError(404, 'Submission not found');

      const [updated] = await db
        .update(homeworkSubmissions)
        .set({
          marksObtained: input.marksObtained === undefined ? submission.marksObtained : input.marksObtained,
          teacherFeedback: input.teacherFeedback === undefined ? submission.teacherFeedback : input.teacherFeedback,
          status: input.status ?? 'reviewed',
          reviewedByStaffId: user.staffId,
          reviewedAt: new Date(),
          updatedAt: new Date(),
        })
        .where(eq(homeworkSubmissions.id, submissionId))
        .returning();

      return updated;
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

    async previewBulkImport(
      user: AuthUser,
      entity: 'students' | 'staff' | 'classes_sections',
      csvText: string,
    ) {
      if (entity === 'students') {
        return BulkImporter.previewStudents(csvText);
      } else if (entity === 'staff') {
        return BulkImporter.previewStaff(csvText);
      } else {
        return BulkImporter.previewClassesSections(csvText);
      }
    },

    async commitBulkImport(
      user: AuthUser,
      input: z.infer<typeof bulkImportCommitSchema>,
    ) {
      if (input.entity === 'classes_sections') {
        let createdClasses = 0;
        let createdSections = 0;
        for (const item of input.records) {
          const className = String(item.className || '').trim();
          const sectionName = String(item.sectionName || '').trim();
          if (!className || !sectionName) continue;

          let [existingClass] = await db
            .select()
            .from(classes)
            .where(and(eq(classes.schoolId, user.schoolId), eq(classes.name, className)))
            .limit(1);

          if (!existingClass) {
            const [newCls] = await db
              .insert(classes)
              .values({
                schoolId: user.schoolId,
                name: className,
                sortOrder: item.gradeOrder ? Number(item.gradeOrder) : 0,
              })
              .returning();
            existingClass = newCls;
            createdClasses++;
          }

          if (existingClass) {
            const [existingSection] = await db
              .select()
              .from(sections)
              .where(and(eq(sections.schoolId, user.schoolId), eq(sections.classId, existingClass.id), eq(sections.name, sectionName)))
              .limit(1);

            if (!existingSection) {
              await db.insert(sections).values({
                schoolId: user.schoolId,
                classId: existingClass.id,
                name: sectionName,
              });
              createdSections++;
            }
          }
        }
        return {
          entity: 'classes_sections',
          success: true,
          createdClasses,
          createdSections,
          totalProcessed: input.records.length,
        };
      }

      if (input.entity === 'staff') {
        let createdStaff = 0;
        for (const item of input.records) {
          const fullName = String(item.fullName || '').trim();
          const email = String(item.email || '').trim().toLowerCase();
          const role = (String(item.role || 'teacher').toLowerCase() === 'admin' ? 'admin' : 'teacher') as 'admin' | 'teacher';
          if (!fullName || !email) continue;

          let [existingUser] = await db
            .select()
            .from(appUsers)
            .where(and(eq(appUsers.schoolId, user.schoolId), eq(appUsers.email, email)))
            .limit(1);

          if (!existingUser) {
            const [newUser] = await db
              .insert(appUsers)
              .values({
                schoolId: user.schoolId,
                neonUserId: `usr_${Math.random().toString(36).substring(2, 10)}`,
                email,
                displayName: fullName,
              })
              .returning();
            existingUser = newUser;

            if (existingUser) {
              await db.insert(userRoles).values({
                userId: existingUser.id,
                role,
              });
            }
          }

          if (existingUser) {
            const [existingStaff] = await db
              .select()
              .from(staff)
              .where(and(eq(staff.schoolId, user.schoolId), eq(staff.userId, existingUser.id)))
              .limit(1);

            if (!existingStaff) {
              const staffCode = item.employeeId
                ? String(item.employeeId).trim()
                : `STF-${Math.random().toString(36).substring(2, 8).toUpperCase()}`;
              await db.insert(staff).values({
                schoolId: user.schoolId,
                userId: existingUser.id,
                staffCode,
                fullName,
                email,
                phone: item.phone ? String(item.phone).trim() : null,
                isTeacher: role === 'teacher',
              });
              createdStaff++;
            }
          }
        }
        return {
          entity: 'staff',
          success: true,
          createdStaff,
          totalProcessed: input.records.length,
        };
      }

      if (input.entity === 'students') {
        let createdStudents = 0;
        let enrolledStudents = 0;
        for (const item of input.records) {
          const fullName = String(item.fullName || '').trim();
          const rollNumber = String(item.rollNumber || '').trim();
          if (!fullName || !rollNumber) continue;

          const admissionNumber = String(item.admissionNumber || rollNumber).trim();
          const [createdStudent] = await db
            .insert(students)
            .values({
              schoolId: user.schoolId,
              fullName,
              admissionNumber,
              guardianName: item.parentName ? String(item.parentName).trim() : null,
              guardianPhone: item.parentPhone ? String(item.parentPhone).trim() : null,
            })
            .returning();
          if (!createdStudent) continue;
          createdStudents++;

          let targetClassId = input.defaultClassId;
          let targetSectionId = input.defaultSectionId;

          if (item.className && item.sectionName) {
            const [cls] = await db
              .select({ id: classes.id })
              .from(classes)
              .where(and(eq(classes.schoolId, user.schoolId), eq(classes.name, String(item.className).trim())))
              .limit(1);
            if (cls) {
              const [sec] = await db
                .select({ id: sections.id })
                .from(sections)
                .where(and(eq(sections.schoolId, user.schoolId), eq(sections.classId, cls.id), eq(sections.name, String(item.sectionName).trim())))
                .limit(1);
              if (sec) {
                targetClassId = cls.id;
                targetSectionId = sec.id;
              }
            }
          }

          if (input.academicYearId && targetClassId && targetSectionId) {
            await db.insert(studentEnrollments).values({
              schoolId: user.schoolId,
              studentId: createdStudent.id,
              academicYearId: input.academicYearId,
              classId: targetClassId,
              sectionId: targetSectionId,
              rollNumber,
            });
            enrolledStudents++;
          }

          if (item.parentEmail) {
            const parentEmailStr = String(item.parentEmail).toLowerCase().trim();
            let [pUser] = await db
              .select({ id: appUsers.id })
              .from(appUsers)
              .where(and(eq(appUsers.schoolId, user.schoolId), eq(appUsers.email, parentEmailStr)))
              .limit(1);
            if (!pUser) {
              const [newPUser] = await db
                .insert(appUsers)
                .values({
                  schoolId: user.schoolId,
                  neonUserId: `parent_${Math.random().toString(36).substring(2, 10)}`,
                  email: parentEmailStr,
                  displayName: item.parentName ? String(item.parentName).trim() : 'Parent',
                })
                .returning();
              if (newPUser) {
                pUser = { id: newPUser.id };
                await db.insert(userRoles).values({
                  userId: newPUser.id,
                  role: 'parent',
                });
              }
            }

            if (pUser) {
              await db
                .insert(studentGuardians)
                .values({
                  schoolId: user.schoolId,
                  studentId: createdStudent.id,
                  appUserId: pUser.id,
                  relationship: 'guardian',
                })
                .onConflictDoNothing();
            }
          }
        }

        return {
          entity: 'students',
          success: true,
          createdStudents,
          enrolledStudents,
          totalProcessed: input.records.length,
        };
      }

      throw new ApiError(400, 'Unsupported entity for bulk import');
    },

    async getOnboardingStatus(user: AuthUser) {
      const [school] = await db
        .select()
        .from(schools)
        .where(eq(schools.id, user.schoolId))
        .limit(1);

      if (!school) throw new ApiError(404, 'School not found');

      const [academicYear] = await db
        .select({ id: academicYears.id, name: academicYears.name })
        .from(academicYears)
        .where(and(eq(academicYears.schoolId, user.schoolId), eq(academicYears.isActive, true)))
        .limit(1);

      const classRows = await db
        .select({ id: classes.id })
        .from(classes)
        .where(eq(classes.schoolId, user.schoolId));

      const staffRows = await db
        .select({ id: staff.id })
        .from(staff)
        .where(eq(staff.schoolId, user.schoolId));

      const studentRows = await db
        .select({ id: students.id })
        .from(students)
        .where(eq(students.schoolId, user.schoolId));

      const isCompleted = !!academicYear && classRows.length > 0 && (staffRows.length > 0 || studentRows.length > 0);

      return {
        isCompleted,
        school: {
          id: school.id,
          name: school.name,
          code: school.code,
        },
        hasAcademicYear: !!academicYear,
        activeAcademicYear: academicYear ?? null,
        classCount: classRows.length,
        staffCount: staffRows.length,
        studentCount: studentRows.length,
      };
    },

    async runOnboardingWizard(user: AuthUser, input: z.infer<typeof onboardingWizardSchema>) {
      await db
        .update(schools)
        .set({ name: input.schoolName, updatedAt: new Date() })
        .where(eq(schools.id, user.schoolId));

      const [year] = await db
        .insert(academicYears)
        .values({
          schoolId: user.schoolId,
          name: input.academicYearName,
          startsOn: input.startDate,
          endsOn: input.endDate,
          isActive: true,
        })
        .returning();

      if (!year) throw new ApiError(500, 'Failed to create academic year');

      const createdClassesList: { id: string; name: string; sections: { id: string; name: string }[] }[] = [];
      let sortOrder = 1;

      for (const cls of input.classes) {
        const [insertedClass] = await db
          .insert(classes)
          .values({
            schoolId: user.schoolId,
            name: cls.name,
            sortOrder: sortOrder++,
          })
          .returning();

        if (!insertedClass) continue;

        const createdSectionsList: { id: string; name: string }[] = [];
        for (const secName of cls.sections) {
          const [insertedSection] = await db
            .insert(sections)
            .values({
              schoolId: user.schoolId,
              classId: insertedClass.id,
              name: secName,
            })
            .returning();
          if (insertedSection) {
            createdSectionsList.push({ id: insertedSection.id, name: insertedSection.name });
          }
        }

        createdClassesList.push({
          id: insertedClass.id,
          name: insertedClass.name,
          sections: createdSectionsList,
        });
      }

      return {
        success: true,
        schoolName: input.schoolName,
        academicYear: year,
        classes: createdClassesList,
      };
    },

    async listNotifications(user: AuthUser, filters: z.infer<typeof notificationQuerySchema>) {
      const conditions = [eq(notifications.schoolId, user.schoolId)];
      if (filters.channel) conditions.push(eq(notifications.channel, filters.channel));
      if (filters.status) conditions.push(eq(notifications.status, filters.status));

      return db
        .select()
        .from(notifications)
        .where(and(...conditions))
        .orderBy(desc(notifications.createdAt))
        .limit(filters.limit ?? 50);
    },

    async sendNotification(
      user: AuthUser,
      input: z.infer<typeof sendNotificationSchema>,
      env?: Partial<Env>,
    ) {
      const service = new NotificationService(env);
      const result = await service.dispatch({
        schoolId: user.schoolId,
        recipientUserId: input.recipientUserId,
        recipientPhone: input.recipientPhone,
        recipientEmail: input.recipientEmail,
        channel: input.channel,
        templateId: input.templateId,
        title: input.title,
        body: input.body,
        data: input.data,
      });

      const [record] = await db
        .insert(notifications)
        .values({
          schoolId: user.schoolId,
          recipientUserId: input.recipientUserId ?? null,
          recipientPhone: input.recipientPhone ?? null,
          recipientEmail: input.recipientEmail ?? null,
          channel: input.channel,
          templateId: input.templateId ?? null,
          title: input.title,
          body: input.body,
          data: input.data ?? null,
          status: result.status,
          failureReason: result.failureReason ?? null,
          sentAt: result.sentAt,
          deliveredAt: result.deliveredAt ?? null,
        })
        .returning();

      return record;
    },

    async triggerAbsenceAlertsForSession(user: AuthUser, sessionId: string, env?: Partial<Env>) {
      const [session] = await db
        .select()
        .from(attendanceSessions)
        .where(and(eq(attendanceSessions.schoolId, user.schoolId), eq(attendanceSessions.id, sessionId)))
        .limit(1);

      if (!session) throw new ApiError(404, 'Attendance session not found');

      const absentRecords = await db
        .select({
          recordId: attendanceRecords.id,
          studentId: attendanceRecords.studentId,
          studentName: students.fullName,
        })
        .from(attendanceRecords)
        .innerJoin(students, eq(attendanceRecords.studentId, students.id))
        .where(
          and(
            eq(attendanceRecords.sessionId, sessionId),
            eq(attendanceRecords.status, 'absent'),
          ),
        );

      if (absentRecords.length === 0) {
        return { totalAbsent: 0, dispatchedCount: 0 };
      }

      const [school] = await db
        .select({ name: schools.name })
        .from(schools)
        .where(eq(schools.id, user.schoolId))
        .limit(1);

      const service = new NotificationService(env);
      let dispatchedCount = 0;

      for (const rec of absentRecords) {
        const [studentDetails] = await db
          .select({
            guardianPhone: students.guardianPhone,
            guardianName: students.guardianName,
            userId: students.userId,
          })
          .from(students)
          .where(and(eq(students.schoolId, user.schoolId), eq(students.id, rec.studentId)))
          .limit(1);

        const content = NotificationService.formatAbsenceAlert(rec.studentName, session.attendanceDate, school?.name);
        const result = await service.dispatch({
          schoolId: user.schoolId,
          recipientUserId: studentDetails?.userId ?? null,
          recipientPhone: studentDetails?.guardianPhone ?? null,
          recipientEmail: null,
          channel: 'sms',
          title: content.title,
          body: content.body,
        });

        await db.insert(notifications).values({
          schoolId: user.schoolId,
          recipientUserId: studentDetails?.userId ?? null,
          recipientPhone: studentDetails?.guardianPhone ?? null,
          recipientEmail: null,
          channel: 'sms',
          title: content.title,
          body: content.body,
          status: result.status,
          failureReason: result.failureReason ?? null,
          sentAt: result.sentAt,
          deliveredAt: result.deliveredAt ?? null,
        });

        dispatchedCount++;
      }

      return { totalAbsent: absentRecords.length, dispatchedCount };
    },

    async triggerPendingFeeReminders(user: AuthUser, daysThreshold: number = 7, env?: Partial<Env>) {
      const now = new Date();
      const cutoff = new Date();
      cutoff.setDate(cutoff.getDate() + daysThreshold);
      const cutoffStr = cutoff.toISOString().slice(0, 10);
      const todayStr = now.toISOString().slice(0, 10);

      const pendingAllocations = await db
        .select({
          allocationId: studentFeeAllocations.id,
          studentId: studentFeeAllocations.studentId,
          studentName: students.fullName,
          feeTitle: feeStructures.name,
          amountDue: studentFeeAllocations.amount,
          dueDate: studentFeeAllocations.dueDate,
          status: studentFeeAllocations.status,
        })
        .from(studentFeeAllocations)
        .innerJoin(students, eq(studentFeeAllocations.studentId, students.id))
        .innerJoin(feeStructures, eq(studentFeeAllocations.feeStructureId, feeStructures.id))
        .where(
          and(
            eq(studentFeeAllocations.schoolId, user.schoolId),
            ne(studentFeeAllocations.status, 'paid'),
            lte(studentFeeAllocations.dueDate, cutoffStr),
          ),
        )
        .limit(100);

      const service = new NotificationService(env);
      let dispatchedCount = 0;

      for (const alloc of pendingAllocations) {
        const isOverdue = alloc.dueDate < todayStr;
        const [studentDetails] = await db
          .select({
            guardianPhone: students.guardianPhone,
            guardianName: students.guardianName,
            userId: students.userId,
          })
          .from(students)
          .where(and(eq(students.schoolId, user.schoolId), eq(students.id, alloc.studentId)))
          .limit(1);

        const content = NotificationService.formatFeeReminder(
          alloc.studentName,
          alloc.feeTitle,
          alloc.amountDue,
          alloc.dueDate,
          isOverdue,
        );

        const result = await service.dispatch({
          schoolId: user.schoolId,
          recipientUserId: studentDetails?.userId ?? null,
          recipientPhone: studentDetails?.guardianPhone ?? null,
          recipientEmail: null,
          channel: 'whatsapp',
          title: content.title,
          body: content.body,
        });

        await db.insert(notifications).values({
          schoolId: user.schoolId,
          recipientUserId: studentDetails?.userId ?? null,
          recipientPhone: studentDetails?.guardianPhone ?? null,
          recipientEmail: null,
          channel: 'whatsapp',
          title: content.title,
          body: content.body,
          status: result.status,
          failureReason: result.failureReason ?? null,
          sentAt: result.sentAt,
          deliveredAt: result.deliveredAt ?? null,
        });

        dispatchedCount++;
      }

      return { totalPending: pendingAllocations.length, dispatchedCount };
    },

    async portalNotifications(user: AuthUser) {
      return db
        .select()
        .from(notifications)
        .where(
          and(
            eq(notifications.schoolId, user.schoolId),
            sql`(${notifications.recipientUserId} = ${user.appUserId} OR ${notifications.recipientUserId} IS NULL)`,
          ),
        )
        .orderBy(desc(notifications.createdAt))
        .limit(50);
    },

    async getTeacherAvailability(user: AuthUser, staffId?: string) {
      const targetStaffId = staffId ?? user.staffId;
      if (!targetStaffId) throw new ApiError(400, 'Teacher staff ID is required');

      const [existing] = await db
        .select()
        .from(teacherAvailabilitySettings)
        .where(and(eq(teacherAvailabilitySettings.schoolId, user.schoolId), eq(teacherAvailabilitySettings.staffId, targetStaffId)))
        .limit(1);

      if (existing) return existing;

      return {
        id: null,
        schoolId: user.schoolId,
        staffId: targetStaffId,
        startTime: '09:00',
        endTime: '16:30',
        availableDays: '1,2,3,4,5',
        autoReplyMessage: 'Thank you for reaching out. I am currently outside my teaching communication hours and will review your message when school resumes.',
        isEnabled: true,
      };
    },

    async updateTeacherAvailability(
      user: AuthUser,
      input: z.infer<typeof updateTeacherAvailabilitySchema>,
      targetStaffId?: string,
    ) {
      const staffId = targetStaffId ?? user.staffId;
      if (!staffId) throw new ApiError(400, 'Teacher staff ID is required');

      const [existing] = await db
        .select({ id: teacherAvailabilitySettings.id })
        .from(teacherAvailabilitySettings)
        .where(and(eq(teacherAvailabilitySettings.schoolId, user.schoolId), eq(teacherAvailabilitySettings.staffId, staffId)))
        .limit(1);

      if (existing) {
        const [updated] = await db
          .update(teacherAvailabilitySettings)
          .set({
            startTime: input.startTime,
            endTime: input.endTime,
            availableDays: input.availableDays,
            autoReplyMessage: input.autoReplyMessage,
            isEnabled: input.isEnabled,
            updatedAt: new Date(),
          })
          .where(eq(teacherAvailabilitySettings.id, existing.id))
          .returning();
        return updated;
      }

      const [created] = await db
        .insert(teacherAvailabilitySettings)
        .values({
          schoolId: user.schoolId,
          staffId,
          startTime: input.startTime,
          endTime: input.endTime,
          availableDays: input.availableDays,
          autoReplyMessage: input.autoReplyMessage,
          isEnabled: input.isEnabled,
        })
        .returning();

      return created;
    },

    async listChatConversations(user: AuthUser) {
      const conditions = [eq(chatConversations.schoolId, user.schoolId)];
      if (user.roles.includes('teacher') && user.staffId) {
        conditions.push(eq(chatConversations.teacherStaffId, user.staffId));
      } else if (user.roles.includes('parent') && !user.roles.includes('admin')) {
        conditions.push(eq(chatConversations.parentAppUserId, user.appUserId));
      }

      const convs = await db
        .select({
          id: chatConversations.id,
          studentId: chatConversations.studentId,
          studentName: students.fullName,
          teacherStaffId: chatConversations.teacherStaffId,
          teacherName: staff.fullName,
          parentAppUserId: chatConversations.parentAppUserId,
          parentName: appUsers.displayName,
          subject: chatConversations.subject,
          status: chatConversations.status,
          lastMessageAt: chatConversations.lastMessageAt,
          createdAt: chatConversations.createdAt,
        })
        .from(chatConversations)
        .innerJoin(students, eq(chatConversations.studentId, students.id))
        .innerJoin(staff, eq(chatConversations.teacherStaffId, staff.id))
        .innerJoin(appUsers, eq(chatConversations.parentAppUserId, appUsers.id))
        .where(and(...conditions))
        .orderBy(desc(chatConversations.lastMessageAt));

      return convs;
    },

    async createChatConversation(
      user: AuthUser,
      input: z.infer<typeof createChatConversationSchema>,
    ) {
      const parentUserId = user.appUserId;

      const [conv] = await db
        .insert(chatConversations)
        .values({
          schoolId: user.schoolId,
          studentId: input.studentId,
          teacherStaffId: input.teacherStaffId,
          parentAppUserId: parentUserId,
          subject: input.subject,
          status: 'active',
          lastMessageAt: new Date(),
        })
        .returning();

      if (!conv) throw new ApiError(500, 'Failed to create conversation');

      let initialMsg = null;
      let autoReplyMsg = null;

      if (input.initialMessage) {
        const [msg] = await db
          .insert(chatMessages)
          .values({
            conversationId: conv.id,
            senderAppUserId: user.appUserId,
            senderRole: user.roles.includes('teacher') ? 'teacher' : 'parent',
            content: input.initialMessage,
            isRead: false,
            isAutoReply: false,
          })
          .returning();
        initialMsg = msg;

        if (!user.roles.includes('teacher')) {
          const avail = await this.getTeacherAvailability(user, input.teacherStaffId);
          if (avail && !isTeacherAvailableNow(avail)) {
            const [reply] = await db
              .insert(chatMessages)
              .values({
                conversationId: conv.id,
                senderAppUserId: user.appUserId,
                senderRole: 'teacher',
                content: avail.autoReplyMessage,
                isRead: false,
                isAutoReply: true,
              })
              .returning();
            autoReplyMsg = reply;
          }
        }
      }

      return {
        conversation: conv,
        initialMessage: initialMsg,
        autoReply: autoReplyMsg,
      };
    },


    async listChatMessages(user: AuthUser, conversationId: string) {
      const [conv] = await db
        .select()
        .from(chatConversations)
        .where(and(eq(chatConversations.schoolId, user.schoolId), eq(chatConversations.id, conversationId)))
        .limit(1);

      if (!conv) throw new ApiError(404, 'Conversation not found');

      const isTeacher = user.staffId && conv.teacherStaffId === user.staffId;
      const isParent = conv.parentAppUserId === user.appUserId;
      const isAdmin = user.roles.includes('admin');

      if (!isTeacher && !isParent && !isAdmin) {
        throw new ApiError(403, 'You do not have access to this conversation');
      }

      await db
        .update(chatMessages)
        .set({ isRead: true })
        .where(
          and(
            eq(chatMessages.conversationId, conversationId),
            ne(chatMessages.senderAppUserId, user.appUserId),
            eq(chatMessages.isRead, false),
          ),
        );

      const msgs = await db
        .select()
        .from(chatMessages)
        .where(eq(chatMessages.conversationId, conversationId))
        .orderBy(chatMessages.createdAt);

      return {
        conversation: conv,
        messages: msgs,
      };
    },

    async sendChatMessage(
      user: AuthUser,
      conversationId: string,
      input: z.infer<typeof sendChatMessageSchema>,
      now: Date = new Date(),
    ) {
      const [conv] = await db
        .select()
        .from(chatConversations)
        .where(and(eq(chatConversations.schoolId, user.schoolId), eq(chatConversations.id, conversationId)))
        .limit(1);

      if (!conv) throw new ApiError(404, 'Conversation not found');

      const isTeacher = user.staffId && conv.teacherStaffId === user.staffId;
      const isParent = conv.parentAppUserId === user.appUserId;
      const isAdmin = user.roles.includes('admin');

      if (!isTeacher && !isParent && !isAdmin) {
        throw new ApiError(403, 'You do not have access to this conversation');
      }

      const senderRole = isTeacher ? 'teacher' : 'parent';

      const [msg] = await db
        .insert(chatMessages)
        .values({
          conversationId,
          senderAppUserId: user.appUserId,
          senderRole,
          content: input.content,
          isRead: false,
          isAutoReply: false,
        })
        .returning();

      await db
        .update(chatConversations)
        .set({ lastMessageAt: now, updatedAt: now })
        .where(eq(chatConversations.id, conversationId));

      let autoReplyMsg = null;
      if (senderRole === 'parent') {
        const avail = await this.getTeacherAvailability(user, conv.teacherStaffId);
        if (avail && !isTeacherAvailableNow(avail, now)) {
          const [reply] = await db
            .insert(chatMessages)
            .values({
              conversationId,
              senderAppUserId: user.appUserId,
              senderRole: 'teacher',
              content: avail.autoReplyMessage,
              isRead: false,
              isAutoReply: true,
            })
            .returning();
          autoReplyMsg = reply;
        }
      }

      return {
        message: msg,
        autoReply: autoReplyMsg,
      };
    },

    // Phase 11: Audit Logging
    async createAuditLog(params: {
      schoolId: string;
      userId?: string | null | undefined;
      userEmail: string;
      userRole: string;
      action: string;
      resourceType: string;
      resourceId?: string | null | undefined;
      ipAddress?: string | null | undefined;
      details?: Record<string, unknown> | null | undefined;
    }) {
      const [log] = await db
        .insert(auditLogs)
        .values({
          schoolId: params.schoolId,
          userId: params.userId ?? null,
          userEmail: params.userEmail,
          userRole: params.userRole,
          action: params.action,
          resourceType: params.resourceType,
          resourceId: params.resourceId ?? null,
          ipAddress: params.ipAddress ?? null,
          details: params.details ?? null,
        })
        .returning();
      return log;
    },

    async listAuditLogs(
      user: AuthUser,
      query: { action?: string | undefined; resourceType?: string | undefined; limit?: number | undefined },
    ) {
      const conditions = [eq(auditLogs.schoolId, user.schoolId)];
      if (query.action) conditions.push(eq(auditLogs.action, query.action));
      if (query.resourceType) conditions.push(eq(auditLogs.resourceType, query.resourceType));

      return db
        .select()
        .from(auditLogs)
        .where(and(...conditions))
        .orderBy(desc(auditLogs.createdAt))
        .limit(query.limit ?? 50);
    },

    // Phase 11: DPDP Consents
    async recordDpdpConsent(
      user: AuthUser,
      input: {
        studentId: string;
        parentGuardianName: string;
        parentGuardianPhone: string;
        consentType: string;
        verifiedVia?: ('portal_submission' | 'signed_form' | 'sms_otp') | undefined;
        ipAddress?: string | null | undefined;
        validUntil?: string | null | undefined;
      },
    ) {
      const [consent] = await db
        .insert(dpdpConsents)
        .values({
          schoolId: user.schoolId,
          studentId: input.studentId,
          parentGuardianName: input.parentGuardianName,
          parentGuardianPhone: input.parentGuardianPhone,
          consentType: input.consentType,
          status: 'granted',
          verifiedVia: input.verifiedVia ?? 'portal_submission',
          ipAddress: input.ipAddress ?? null,
          validUntil: input.validUntil ? new Date(input.validUntil) : null,
        })
        .returning();

      await this.createAuditLog({
        schoolId: user.schoolId,
        userId: user.appUserId,
        userEmail: user.email,
        userRole: user.roles[0] ?? 'admin',
        action: 'record_dpdp_consent',
        resourceType: 'dpdp_consent',
        resourceId: consent?.id,
        details: { consentType: input.consentType, studentId: input.studentId },
      });

      return consent;
    },

    async listDpdpConsents(
      user: AuthUser,
      query?: { studentId?: string | undefined; status?: ('granted' | 'revoked' | 'expired') | undefined } | undefined,
    ) {
      const conditions = [eq(dpdpConsents.schoolId, user.schoolId)];
      if (query?.studentId) conditions.push(eq(dpdpConsents.studentId, query.studentId));
      if (query?.status) conditions.push(eq(dpdpConsents.status, query.status));

      return db
        .select({
          id: dpdpConsents.id,
          studentId: dpdpConsents.studentId,
          studentName: students.fullName,
          parentGuardianName: dpdpConsents.parentGuardianName,
          parentGuardianPhone: dpdpConsents.parentGuardianPhone,
          consentType: dpdpConsents.consentType,
          status: dpdpConsents.status,
          verifiedVia: dpdpConsents.verifiedVia,
          validUntil: dpdpConsents.validUntil,
          createdAt: dpdpConsents.createdAt,
        })
        .from(dpdpConsents)
        .leftJoin(students, eq(students.id, dpdpConsents.studentId))
        .where(and(...conditions))
        .orderBy(desc(dpdpConsents.createdAt))
        .limit(100);
    },

    // Phase 11: Data Subject Rights (DSR) Requests
    async createDsrRequest(
      user: AuthUser,
      input: {
        studentId?: string | null | undefined;
        requestType: 'data_access' | 'data_rectification' | 'data_erasure_anonymization';
        reason: string;
      },
    ) {
      const [req] = await db
        .insert(dataSubjectRequests)
        .values({
          schoolId: user.schoolId,
          requesterUserId: user.appUserId,
          requesterRole: user.roles[0] ?? 'parent',
          studentId: input.studentId ?? null,
          requestType: input.requestType,
          status: 'pending',
          reason: input.reason,
        })
        .returning();

      await this.createAuditLog({
        schoolId: user.schoolId,
        userId: user.appUserId,
        userEmail: user.email,
        userRole: user.roles[0] ?? 'parent',
        action: 'create_dsr_request',
        resourceType: 'data_subject_request',
        resourceId: req?.id,
        details: { requestType: input.requestType },
      });

      return req;
    },

    async listDsrRequests(
      user: AuthUser,
      status?: ('pending' | 'in_review' | 'fulfilled' | 'rejected') | undefined,
    ) {
      const conditions = [eq(dataSubjectRequests.schoolId, user.schoolId)];
      if (status) conditions.push(eq(dataSubjectRequests.status, status));

      return db
        .select({
          id: dataSubjectRequests.id,
          requesterUserId: dataSubjectRequests.requesterUserId,
          requesterRole: dataSubjectRequests.requesterRole,
          studentId: dataSubjectRequests.studentId,
          studentName: students.fullName,
          requestType: dataSubjectRequests.requestType,
          status: dataSubjectRequests.status,
          reason: dataSubjectRequests.reason,
          resolutionNotes: dataSubjectRequests.resolutionNotes,
          resolvedAt: dataSubjectRequests.resolvedAt,
          createdAt: dataSubjectRequests.createdAt,
        })
        .from(dataSubjectRequests)
        .leftJoin(students, eq(students.id, dataSubjectRequests.studentId))
        .where(and(...conditions))
        .orderBy(desc(dataSubjectRequests.createdAt))
        .limit(100);
    },

    async resolveDsrRequest(
      user: AuthUser,
      id: string,
      input: {
        status: 'fulfilled' | 'rejected' | 'in_review';
        resolutionNotes: string;
        anonymizeStudent?: boolean | undefined;
      },
    ) {
      const [req] = await db
        .select()
        .from(dataSubjectRequests)
        .where(and(eq(dataSubjectRequests.id, id), eq(dataSubjectRequests.schoolId, user.schoolId)))
        .limit(1);

      if (!req) throw new ApiError(404, 'Data subject request not found');

      if (input.status === 'fulfilled' && input.anonymizeStudent && req.studentId) {
        await this.anonymizeStudent(user, req.studentId);
      }

      const [updated] = await db
        .update(dataSubjectRequests)
        .set({
          status: input.status,
          resolutionNotes: input.resolutionNotes,
          resolvedAt: new Date(),
          resolvedByUserId: user.appUserId,
          updatedAt: new Date(),
        })
        .where(eq(dataSubjectRequests.id, id))
        .returning();

      await this.createAuditLog({
        schoolId: user.schoolId,
        userId: user.appUserId,
        userEmail: user.email,
        userRole: user.roles[0] ?? 'admin',
        action: 'resolve_dsr_request',
        resourceType: 'data_subject_request',
        resourceId: id,
        details: { status: input.status, anonymized: !!input.anonymizeStudent },
      });

      return updated;
    },

    async anonymizeStudent(user: AuthUser, studentId: string) {
      const [student] = await db
        .select()
        .from(students)
        .where(and(eq(students.id, studentId), eq(students.schoolId, user.schoolId)))
        .limit(1);

      if (!student) throw new ApiError(404, 'Student not found');

      await db
        .update(students)
        .set({
          fullName: `Anonymized Student (${student.admissionNumber})`,
          guardianName: 'Redacted (DPDP)',
          guardianPhone: '0000000000',
          updatedAt: new Date(),
        })
        .where(eq(students.id, studentId));

      await this.createAuditLog({
        schoolId: user.schoolId,
        userId: user.appUserId,
        userEmail: user.email,
        userRole: user.roles[0] ?? 'admin',
        action: 'anonymize_student_record',
        resourceType: 'student',
        resourceId: studentId,
        details: { reason: 'DPDP Right to Erasure / Anonymization fulfilled' },
      });

      return { success: true, studentId };
    },

    // Phase 11: Enterprise Roles & Class Teacher Assignment
    async assignSectionClassTeacher(
      user: AuthUser,
      sectionId: string,
      classTeacherStaffId: string | null | undefined,
    ) {
      const [section] = await db
        .update(sections)
        .set({
          classTeacherStaffId: classTeacherStaffId ?? null,
          updatedAt: new Date(),
        })
        .where(and(eq(sections.id, sectionId), eq(sections.schoolId, user.schoolId)))
        .returning();

      if (!section) throw new ApiError(404, 'Section not found');

      await this.createAuditLog({
        schoolId: user.schoolId,
        userId: user.appUserId,
        userEmail: user.email,
        userRole: user.roles[0] ?? 'admin',
        action: 'assign_class_teacher',
        resourceType: 'section',
        resourceId: sectionId,
        details: { classTeacherStaffId: classTeacherStaffId ?? null },
      });

      return section;
    },

    // Phase 11: Fee Structure Heads
    async createFeeStructureHead(
      user: AuthUser,
      input: {
        feeStructureId: string;
        headName: string;
        amount: number;
        isOptional?: boolean | undefined;
      },
    ) {
      const [head] = await db
        .insert(feeStructureHeads)
        .values({
          schoolId: user.schoolId,
          feeStructureId: input.feeStructureId,
          headName: input.headName,
          amount: input.amount,
          isOptional: input.isOptional ?? false,
        })
        .returning();
      return head;
    },

    async listFeeStructureHeads(user: AuthUser, feeStructureId: string) {
      return db
        .select()
        .from(feeStructureHeads)
        .where(and(eq(feeStructureHeads.schoolId, user.schoolId), eq(feeStructureHeads.feeStructureId, feeStructureId)))
        .orderBy(desc(feeStructureHeads.createdAt));
    },

    // Phase 11: Fee Concessions
    async createFeeConcession(
      user: AuthUser,
      input: {
        name: string;
        code: string;
        type: 'percentage' | 'flat';
        value: number;
        category: 'merit' | 'sibling' | 'staff_ward' | 'financial_aid' | 'sports';
      },
    ) {
      const [concession] = await db
        .insert(feeConcessions)
        .values({
          schoolId: user.schoolId,
          name: input.name,
          code: input.code.toUpperCase(),
          type: input.type,
          value: input.value,
          category: input.category,
        })
        .returning();

      await this.createAuditLog({
        schoolId: user.schoolId,
        userId: user.appUserId,
        userEmail: user.email,
        userRole: user.roles[0] ?? 'accountant',
        action: 'create_fee_concession',
        resourceType: 'fee_concession',
        resourceId: concession?.id,
        details: { name: input.name, code: input.code, type: input.type, value: input.value },
      });

      return concession;
    },

    async listFeeConcessions(user: AuthUser) {
      return db
        .select()
        .from(feeConcessions)
        .where(eq(feeConcessions.schoolId, user.schoolId))
        .orderBy(desc(feeConcessions.createdAt));
    },

    async applyStudentConcession(
      user: AuthUser,
      input: {
        studentId: string;
        allocationId: string;
        concessionId: string;
        reason?: string | undefined;
      },
    ) {
      const [alloc] = await db
        .select()
        .from(studentFeeAllocations)
        .where(and(eq(studentFeeAllocations.id, input.allocationId), eq(studentFeeAllocations.schoolId, user.schoolId)))
        .limit(1);

      if (!alloc) throw new ApiError(404, 'Fee allocation not found');

      const [concession] = await db
        .select()
        .from(feeConcessions)
        .where(and(eq(feeConcessions.id, input.concessionId), eq(feeConcessions.schoolId, user.schoolId)))
        .limit(1);

      if (!concession) throw new ApiError(404, 'Concession policy not found');

      let discount = 0;
      if (concession.type === 'percentage') {
        discount = Math.round((alloc.amount * concession.value) / 100);
      } else {
        discount = Math.min(concession.value, alloc.amount);
      }

      const [studentConcession] = await db
        .insert(studentFeeConcessions)
        .values({
          schoolId: user.schoolId,
          studentId: input.studentId,
          allocationId: input.allocationId,
          concessionId: input.concessionId,
          appliedAmount: discount,
          reason: input.reason ?? null,
          approvedByUserId: user.appUserId,
        })
        .returning();

      const newAmount = Math.max(0, alloc.amount - discount);
      await db
        .update(studentFeeAllocations)
        .set({
          amount: newAmount,
          status: newAmount === 0 ? 'paid' : alloc.status,
          updatedAt: new Date(),
        })
        .where(eq(studentFeeAllocations.id, alloc.id));

      await this.createAuditLog({
        schoolId: user.schoolId,
        userId: user.appUserId,
        userEmail: user.email,
        userRole: user.roles[0] ?? 'accountant',
        action: 'apply_student_concession',
        resourceType: 'student_fee_concession',
        resourceId: studentConcession?.id,
        details: { allocationId: alloc.id, originalAmount: alloc.amount, discount, newAmount },
      });

      return {
        concession: studentConcession,
        newAllocationAmount: newAmount,
      };
    },

    async listStudentConcessions(
      user: AuthUser,
      query?: { studentId?: string | undefined; allocationId?: string | undefined } | undefined,
    ) {
      const conditions = [eq(studentFeeConcessions.schoolId, user.schoolId)];
      if (query?.studentId) conditions.push(eq(studentFeeConcessions.studentId, query.studentId));
      if (query?.allocationId) conditions.push(eq(studentFeeConcessions.allocationId, query.allocationId));

      return db
        .select({
          id: studentFeeConcessions.id,
          studentId: studentFeeConcessions.studentId,
          studentName: students.fullName,
          allocationId: studentFeeConcessions.allocationId,
          concessionName: feeConcessions.name,
          concessionCode: feeConcessions.code,
          appliedAmount: studentFeeConcessions.appliedAmount,
          reason: studentFeeConcessions.reason,
          createdAt: studentFeeConcessions.createdAt,
        })
        .from(studentFeeConcessions)
        .leftJoin(students, eq(students.id, studentFeeConcessions.studentId))
        .leftJoin(feeConcessions, eq(feeConcessions.id, studentFeeConcessions.concessionId))
        .where(and(...conditions))
        .orderBy(desc(studentFeeConcessions.createdAt));
    },

    // Phase 11: Fee Refunds
    async createFeeRefund(
      user: AuthUser,
      input: {
        allocationId: string;
        studentId: string;
        paymentId?: string | null | undefined;
        amount: number;
        reason: string;
        mode?: ('bank_transfer' | 'cash' | 'cheque' | 'gateway_refund') | undefined;
        referenceNumber?: string | null | undefined;
      },
    ) {
      const refundNumber = `REF-${Date.now().toString(36).toUpperCase()}-${Math.floor(Math.random() * 1000)}`;

      const [refund] = await db
        .insert(feeRefunds)
        .values({
          schoolId: user.schoolId,
          allocationId: input.allocationId,
          studentId: input.studentId,
          paymentId: input.paymentId ?? null,
          refundNumber,
          amount: input.amount,
          reason: input.reason,
          mode: input.mode ?? 'bank_transfer',
          referenceNumber: input.referenceNumber ?? null,
          status: 'pending',
          approvedByUserId: user.appUserId,
        })
        .returning();

      await this.createAuditLog({
        schoolId: user.schoolId,
        userId: user.appUserId,
        userEmail: user.email,
        userRole: user.roles[0] ?? 'accountant',
        action: 'create_fee_refund',
        resourceType: 'fee_refund',
        resourceId: refund?.id,
        details: { refundNumber, amount: input.amount, reason: input.reason },
      });

      return refund;
    },

    async listFeeRefunds(
      user: AuthUser,
      status?: ('pending' | 'approved' | 'processed' | 'rejected') | undefined,
    ) {
      const conditions = [eq(feeRefunds.schoolId, user.schoolId)];
      if (status) conditions.push(eq(feeRefunds.status, status));

      return db
        .select({
          id: feeRefunds.id,
          refundNumber: feeRefunds.refundNumber,
          studentId: feeRefunds.studentId,
          studentName: students.fullName,
          allocationId: feeRefunds.allocationId,
          amount: feeRefunds.amount,
          reason: feeRefunds.reason,
          mode: feeRefunds.mode,
          referenceNumber: feeRefunds.referenceNumber,
          status: feeRefunds.status,
          processedAt: feeRefunds.processedAt,
          createdAt: feeRefunds.createdAt,
        })
        .from(feeRefunds)
        .leftJoin(students, eq(students.id, feeRefunds.studentId))
        .where(and(...conditions))
        .orderBy(desc(feeRefunds.createdAt));
    },

    async updateFeeRefundStatus(user: AuthUser, refundId: string, status: 'approved' | 'processed' | 'rejected') {
      const [refund] = await db
        .update(feeRefunds)
        .set({
          status,
          processedAt: status === 'processed' ? new Date() : null,
          approvedByUserId: user.appUserId,
          updatedAt: new Date(),
        })
        .where(and(eq(feeRefunds.id, refundId), eq(feeRefunds.schoolId, user.schoolId)))
        .returning();

      if (!refund) throw new ApiError(404, 'Refund not found');

      await this.createAuditLog({
        schoolId: user.schoolId,
        userId: user.appUserId,
        userEmail: user.email,
        userRole: user.roles[0] ?? 'accountant',
        action: `refund_${status}`,
        resourceType: 'fee_refund',
        resourceId: refundId,
        details: { status, amount: refund.amount },
      });

      return refund;
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
  submission?: typeof homeworkSubmissions.$inferSelect | null;
}) {
  return {
    ...row.assignment,
    className: row.className,
    sectionName: row.sectionName,
    subjectName: row.subjectName,
    teacherName: row.teacherName,
    submission: row.submission
      ? {
          id: row.submission.id,
          content: row.submission.content,
          attachmentUrl: row.submission.attachmentUrl,
          status: row.submission.status,
          marksObtained: row.submission.marksObtained,
          teacherFeedback: row.submission.teacherFeedback,
          submittedAt: row.submission.submittedAt,
          reviewedAt: row.submission.reviewedAt,
        }
      : null,
  };
}

function examWithLabels(row: {
  exam: typeof exams.$inferSelect;
  className: string;
  sectionName: string;
  subjectName: string | null;
}) {
  return {
    ...row.exam,
    className: row.className,
    sectionName: row.sectionName,
    subjectName: row.subjectName,
  };
}

function examResultWithLabels(row: {
  exam: typeof exams.$inferSelect;
  mark: typeof examMarks.$inferSelect;
  subjectName: string | null;
  teacherName: string;
}) {
  return {
    id: row.mark.id,
    examId: row.exam.id,
    name: row.exam.name,
    examDate: row.exam.examDate,
    subjectId: row.exam.subjectId,
    subjectName: row.subjectName,
    marksObtained: row.mark.marksObtained,
    maxMarks: row.exam.maxMarks,
    percentage: Math.round((row.mark.marksObtained / row.exam.maxMarks) * 1000) / 10,
    remarks: row.mark.remarks,
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

async function assertExamContext(
  db: Db,
  user: AuthUser,
  input: {
    academicYearId?: string | undefined;
    classId?: string | undefined;
    sectionId?: string | undefined;
    subjectId?: string | null | undefined;
  },
) {
  if (input.academicYearId) {
    const [year] = await db
      .select({ id: academicYears.id })
      .from(academicYears)
      .where(and(eq(academicYears.schoolId, user.schoolId), eq(academicYears.id, input.academicYearId)))
      .limit(1);
    if (!year) throw new ApiError(422, 'Selected academic year is not available');
  }
  if (input.classId) {
    const [klass] = await db
      .select({ id: classes.id })
      .from(classes)
      .where(and(eq(classes.schoolId, user.schoolId), eq(classes.id, input.classId)))
      .limit(1);
    if (!klass) throw new ApiError(422, 'Selected class is not available');
  }
  if (input.sectionId) {
    const [section] = await db
      .select({ id: sections.id })
      .from(sections)
      .where(and(eq(sections.schoolId, user.schoolId), eq(sections.id, input.sectionId)))
      .limit(1);
    if (!section) throw new ApiError(422, 'Selected section is not available');
  }
  if (input.subjectId) {
    const [subject] = await db
      .select({ id: subjects.id })
      .from(subjects)
      .where(and(eq(subjects.schoolId, user.schoolId), eq(subjects.id, input.subjectId)))
      .limit(1);
    if (!subject) throw new ApiError(422, 'Selected subject is not available');
  }
}

async function assertTeacherCanManageExam(db: Db, user: AuthUser, examId: string) {
  if (!user.staffId) throw new ApiError(403, 'Teacher profile is required');
  const [exam] = await db
    .select()
    .from(exams)
    .where(and(eq(exams.schoolId, user.schoolId), eq(exams.id, examId)))
    .limit(1);
  if (!exam) throw new ApiError(404, 'Exam not found');

  const predicates = [
    eq(teacherAssignments.schoolId, user.schoolId),
    eq(teacherAssignments.staffId, user.staffId),
    eq(teacherAssignments.academicYearId, exam.academicYearId),
    eq(teacherAssignments.classId, exam.classId),
    eq(teacherAssignments.sectionId, exam.sectionId),
  ];
  if (exam.subjectId) predicates.push(eq(teacherAssignments.subjectId, exam.subjectId));

  const [assignment] = await db.select({ id: teacherAssignments.id }).from(teacherAssignments).where(and(...predicates)).limit(1);
  if (!assignment) throw new ApiError(403, 'Teacher is not assigned to this exam section');
  return exam;
}

function examContextKey(input: {
  academicYearId: string;
  classId: string;
  sectionId: string;
  subjectId?: string | null;
}) {
  return `${input.academicYearId}:${input.classId}:${input.sectionId}:${input.subjectId ?? ''}`;
}

function sqlExcluded(column: string) {
  return sql.raw(`excluded.${column}`);
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

function isTeacherAvailableNow(
  settings: {
    startTime: string;
    endTime: string;
    availableDays: string;
    isEnabled: boolean;
  },
  now: Date = new Date(),
): boolean {
  if (!settings.isEnabled) return true;

  const currentDay = now.getDay() === 0 ? 7 : now.getDay();
  const allowedDays = settings.availableDays.split(',').map((s) => Number(s.trim()));
  if (!allowedDays.includes(currentDay)) {
    return false;
  }

  const currentMinutes = now.getHours() * 60 + now.getMinutes();
  const [startH, startM] = settings.startTime.split(':').map(Number);
  const [endH, endM] = settings.endTime.split(':').map(Number);
  const startMinutes = (startH ?? 0) * 60 + (startM ?? 0);
  const endMinutes = (endH ?? 0) * 60 + (endM ?? 0);

  return currentMinutes >= startMinutes && currentMinutes <= endMinutes;
}

export function calculateLateFee(
  dueDateStr: string,
  baseAmount: number,
  policy: {
    lateFeeGracePeriodDays: number;
    lateFeeType: string; // 'none' | 'flat' | 'daily'
    lateFeeAmount: number;
  },
  now: Date = new Date(),
): { isOverdue: boolean; lateFee: number; totalDue: number; daysLate: number } {
  const dueDate = new Date(dueDateStr);
  const graceDate = new Date(dueDate);
  graceDate.setDate(graceDate.getDate() + (policy.lateFeeGracePeriodDays || 0));

  if (now <= graceDate || policy.lateFeeType === 'none' || policy.lateFeeAmount <= 0) {
    return {
      isOverdue: now > dueDate,
      lateFee: 0,
      totalDue: baseAmount,
      daysLate: 0,
    };
  }

  const msPerDay = 24 * 60 * 60 * 1000;
  const daysLate = Math.max(1, Math.floor((now.getTime() - graceDate.getTime()) / msPerDay));

  let lateFee = 0;
  if (policy.lateFeeType === 'flat') {
    lateFee = policy.lateFeeAmount;
  } else if (policy.lateFeeType === 'daily') {
    lateFee = policy.lateFeeAmount * daysLate;
  }

  return {
    isOverdue: true,
    lateFee,
    totalDue: baseAmount + lateFee,
    daysLate,
  };
}

