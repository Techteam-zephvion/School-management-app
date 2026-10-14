import { describe, expect, it } from 'vitest';
import {
  aiAttendanceInsightsSchema,
  createAnnouncementSchema,
  createHomeworkAssignmentSchema,
  createExamSchema,
  saveExamMarksSchema,
  createStudentGuardianLinkSchema,
  createStudentSchema,
  createTeacherMaterialSchema,
  createUserSchema,
  createTimetableEntrySchema,
  saveAttendanceSchema,
  teacherCopilotSchema,
  updateTimetableEntrySchema,
  createFeeStructureSchema,
  updateFeeStructureSchema,
  createFeeAllocationSchema,
  recordFeePaymentSchema,
  createAdmissionApplicationSchema,
  updateAdmissionApplicationSchema,
  enrollApplicantSchema,
  admissionQuerySchema,
  addAdmissionDocumentSchema,
  updateAdmissionDocumentSchema,
} from '../src/http/validation';


const uuid = '00000000-0000-4000-8000-000000000001';

describe('attendance validation', () => {
  it('accepts daily attendance without subject or period', () => {
    const parsed = saveAttendanceSchema.parse({
      academicYearId: uuid,
      classId: uuid,
      sectionId: uuid,
      kind: 'daily',
      attendanceDate: '2026-10-10',
      records: [{ studentId: uuid, status: 'present' }],
    });

    expect(parsed.kind).toBe('daily');
  });

  it('requires subject and period for period-wise attendance', () => {
    const parsed = saveAttendanceSchema.safeParse({
      academicYearId: uuid,
      classId: uuid,
      sectionId: uuid,
      kind: 'period',
      attendanceDate: '2026-10-10',
      records: [{ studentId: uuid, status: 'present' }],
    });

    expect(parsed.success).toBe(false);
  });
});

describe('homework validation', () => {
  it('accepts bounded teacher homework payloads', () => {
    const parsed = createHomeworkAssignmentSchema.parse({
      academicYearId: uuid,
      classId: uuid,
      sectionId: uuid,
      subjectId: uuid,
      title: 'Read chapter 4',
      instructions: 'Complete the reading notes and answer questions 1-5.',
      dueDate: '2026-10-16',
      estimatedMinutes: 30,
    });

    expect(parsed.status).toBe('published');
  });

  it('rejects homework without useful instructions', () => {
    const parsed = createHomeworkAssignmentSchema.safeParse({
      academicYearId: uuid,
      classId: uuid,
      sectionId: uuid,
      title: 'HW',
      instructions: '',
      dueDate: '2026-10-16',
    });

    expect(parsed.success).toBe(false);
  });
});

describe('exam validation', () => {
  it('accepts exam setup and mark entry payloads', () => {
    const exam = createExamSchema.parse({
      academicYearId: uuid,
      classId: uuid,
      sectionId: uuid,
      subjectId: uuid,
      name: 'Term 1 Mathematics',
      examDate: '2026-10-20',
      maxMarks: 100,
      status: 'published',
    });
    const marks = saveExamMarksSchema.parse({
      examId: uuid,
      records: [{ studentId: uuid, marksObtained: 82, remarks: 'Good work' }],
    });

    expect(exam.status).toBe('published');
    expect(marks.records[0]?.marksObtained).toBe(82);
  });

  it('rejects impossible mark values', () => {
    const parsed = saveExamMarksSchema.safeParse({
      examId: uuid,
      records: [{ studentId: uuid, marksObtained: -1 }],
    });

    expect(parsed.success).toBe(false);
  });
});

describe('timetable validation', () => {
  const entry = {
    academicYearId: uuid,
    classId: uuid,
    sectionId: uuid,
    subjectId: uuid,
    staffId: uuid,
    dayOfWeek: 1,
    startTime: '09:00',
    endTime: '09:45',
    periodNumber: 1,
  };

  it('accepts a valid lesson block', () => {
    const parsed = createTimetableEntrySchema.parse(entry);

    expect(parsed.dayOfWeek).toBe(1);
    expect(parsed.startTime).toBe('09:00');
  });

  it('rejects malformed clock times', () => {
    const parsed = createTimetableEntrySchema.safeParse({
      ...entry,
      startTime: '9:00',
    });

    expect(parsed.success).toBe(false);
  });

  it('rejects lessons that end before they start', () => {
    const parsed = createTimetableEntrySchema.safeParse({
      ...entry,
      endTime: '08:55',
    });

    expect(parsed.success).toBe(false);
  });

  it('allows partial updates while validating complete time changes', () => {
    expect(updateTimetableEntrySchema.safeParse({ label: 'Lab' }).success).toBe(true);
    expect(updateTimetableEntrySchema.safeParse({ startTime: '11:00', endTime: '10:30' }).success).toBe(false);
  });
});

describe('AI feature validation', () => {
  it('accepts bounded admin insight filters', () => {
    const parsed = aiAttendanceInsightsSchema.parse({
      startDate: '2026-10-01',
      endDate: '2026-10-10',
      classId: uuid,
    });

    expect(parsed.endDate).toBe('2026-10-10');
  });

  it('rejects admin insight ranges that end before they start', () => {
    const parsed = aiAttendanceInsightsSchema.safeParse({
      startDate: '2026-10-10',
      endDate: '2026-10-01',
    });

    expect(parsed.success).toBe(false);
  });

  it('defaults safe teacher copilot options', () => {
    const parsed = teacherCopilotSchema.parse({
      outputType: 'quiz',
      topic: 'Linear equations',
    });

    expect(parsed.durationMinutes).toBe(40);
    expect(parsed.questionCount).toBe(10);
    expect(parsed.difficulty).toBe('standard');
    expect(parsed.language).toBe('English');
  });

  it('rejects oversized teacher copilot output requests', () => {
    const parsed = teacherCopilotSchema.safeParse({
      outputType: 'worksheet',
      topic: 'Fractions',
      durationMinutes: 240,
    });

    expect(parsed.success).toBe(false);
  });

  it('accepts structured teacher material drafts for persistence', () => {
    const parsed = createTeacherMaterialSchema.parse({
      type: 'lesson_plan',
      title: 'Fractions warmup',
      topic: 'Fractions',
      difficulty: 'standard',
      classId: uuid,
      sectionId: uuid,
      subjectId: uuid,
      content: {
        overview: 'A short draft.',
        sections: [{ heading: 'Start', items: ['Review equivalent fractions.'] }],
        checksForUnderstanding: ['Ask students to simplify 2/4.'],
        teacherNotes: ['Expected answer: 1/2.'],
      },
    });

    expect(parsed.language).toBe('English');
    expect(parsed.content.sections[0]?.heading).toBe('Start');
  });
});

describe('announcement validation', () => {
  it('accepts school-wide announcements without a class target', () => {
    const parsed = createAnnouncementSchema.parse({
      audience: 'school',
      title: 'Holiday notice',
      body: 'The school will remain closed tomorrow.',
    });

    expect(parsed.priority).toBe('normal');
    expect(parsed.audience).toBe('school');
  });

  it('requires class and section for class-section announcements', () => {
    const parsed = createAnnouncementSchema.safeParse({
      audience: 'class_section',
      title: 'Bring notebooks',
      body: 'Please bring your mathematics notebook tomorrow.',
    });

    expect(parsed.success).toBe(false);
  });

  it('rejects class targets on school-wide announcements', () => {
    const parsed = createAnnouncementSchema.safeParse({
      audience: 'school',
      classId: uuid,
      sectionId: uuid,
      title: 'Invalid target',
      body: 'This should not mix whole-school and class-section targets.',
    });

    expect(parsed.success).toBe(false);
  });
});

describe('portal account validation', () => {
  it('accepts student account links while creating a student', () => {
    const parsed = createStudentSchema.parse({
      admissionNumber: 'S-100',
      fullName: 'Student User',
      userId: uuid,
      academicYearId: uuid,
      classId: uuid,
      sectionId: uuid,
    });

    expect(parsed.userId).toBe(uuid);
  });

  it('accepts parent guardian links', () => {
    const parsed = createStudentGuardianLinkSchema.parse({
      studentId: uuid,
      appUserId: uuid,
      relationship: 'mother',
    });

    expect(parsed.relationship).toBe('mother');
  });

  it('allows provisioning student and parent roles', () => {
    const parsed = createUserSchema.parse({
      neonUserId: 'neon-parent-1',
      email: 'parent@schoolic.local',
      displayName: 'Parent User',
      roles: ['parent', 'student'],
    });

    expect(parsed.roles).toEqual(['parent', 'student']);
  });
});

describe('fee management validation', () => {
  it('accepts a valid fee structure', () => {
    const parsed = createFeeStructureSchema.parse({
      academicYearId: uuid,
      name: 'Term 1 Tuition Fee',
      code: 'TUIT-T1-2026',
      amount: 25000,
      frequency: 'term',
      dueDate: '2026-11-15',
    });

    expect(parsed.name).toBe('Term 1 Tuition Fee');
    expect(parsed.amount).toBe(25000);
    expect(parsed.frequency).toBe('term');
  });

  it('rejects negative or zero fee structure amounts', () => {
    const parsed = createFeeStructureSchema.safeParse({
      academicYearId: uuid,
      name: 'Lab Fee',
      code: 'LAB-01',
      amount: -500,
    });

    expect(parsed.success).toBe(false);
  });

  it('accepts valid fee allocations', () => {
    const parsed = createFeeAllocationSchema.parse({
      studentId: uuid,
      feeStructureId: uuid,
      academicYearId: uuid,
      amount: 15000,
      dueDate: '2026-11-30',
    });

    expect(parsed.amount).toBe(15000);
    expect(parsed.dueDate).toBe('2026-11-30');
  });

  it('accepts valid fee payments with different payment methods', () => {
    const parsed = recordFeePaymentSchema.parse({
      allocationId: uuid,
      amountPaid: 15000,
      paymentMethod: 'upi',
      transactionReference: 'UPI/123456789/REF',
      notes: 'Paid via phonepe',
    });

    expect(parsed.paymentMethod).toBe('upi');
    expect(parsed.amountPaid).toBe(15000);
  });

  it('rejects non-positive payment amounts', () => {
    const parsed = recordFeePaymentSchema.safeParse({
      allocationId: uuid,
      amountPaid: 0,
      paymentMethod: 'cash',
    });

    expect(parsed.success).toBe(false);
  });
});

describe('admissions validation', () => {
  it('accepts valid admission applications with default status', () => {
    const parsed = createAdmissionApplicationSchema.parse({
      academicYearId: uuid,
      applyingForClassId: uuid,
      applicantName: 'Aarav Sharma',
      parentName: 'Rajesh Sharma',
      parentPhone: '+91 9876543210',
      parentEmail: 'rajesh.sharma@example.com',
      gender: 'male',
      dateOfBirth: '2018-05-12',
      previousSchool: 'Sunrise Kindergarten',
    });

    expect(parsed.applicantName).toBe('Aarav Sharma');
    expect(parsed.status).toBe('applied');
    expect(parsed.parentPhone).toBe('+91 9876543210');
  });

  it('accepts admission applications with custom documents checklist', () => {
    const parsed = createAdmissionApplicationSchema.parse({
      academicYearId: uuid,
      applyingForClassId: uuid,
      applicantName: 'Priya Patel',
      parentName: 'Sunita Patel',
      parentPhone: '9876543211',
      status: 'under_review',
      documents: [
        { title: 'Birth Certificate', status: 'verified', documentNumber: 'BC-2018-992' },
        { title: 'Transfer Certificate', status: 'pending' },
      ],
    });

    expect(parsed.status).toBe('under_review');
    expect(parsed.documents).toHaveLength(2);
    expect(parsed.documents?.[0]?.status).toBe('verified');
  });

  it('rejects admission applications with invalid phone or empty applicant name', () => {
    const invalidPhone = createAdmissionApplicationSchema.safeParse({
      academicYearId: uuid,
      applyingForClassId: uuid,
      applicantName: 'Aarav Sharma',
      parentName: 'Rajesh Sharma',
      parentPhone: '123',
    });
    expect(invalidPhone.success).toBe(false);

    const emptyName = createAdmissionApplicationSchema.safeParse({
      academicYearId: uuid,
      applyingForClassId: uuid,
      applicantName: '',
      parentName: 'Rajesh Sharma',
      parentPhone: '9876543210',
    });
    expect(emptyName.success).toBe(false);
  });

  it('accepts partial application updates and status transitions', () => {
    const update = updateAdmissionApplicationSchema.parse({
      status: 'approved',
      decisionDate: '2026-10-15',
      notes: 'Passed entrance interview successfully',
    });

    expect(update.status).toBe('approved');
    expect(update.decisionDate).toBe('2026-10-15');
  });

  it('accepts valid enrollment payload', () => {
    const enrollment = enrollApplicantSchema.parse({
      sectionId: uuid,
      admissionNumber: 'ADM-2026-0042',
      rollNumber: '14',
    });

    expect(enrollment.sectionId).toBe(uuid);
    expect(enrollment.admissionNumber).toBe('ADM-2026-0042');
  });

  it('accepts admission search and status query filters', () => {
    const query = admissionQuerySchema.parse({
      status: 'applied',
      search: 'Sharma',
      classId: uuid,
    });

    expect(query.status).toBe('applied');
    expect(query.search).toBe('Sharma');
  });

  it('validates document additions and updates', () => {
    const doc = addAdmissionDocumentSchema.parse({
      title: 'Previous School Report Card',
      status: 'submitted',
      documentNumber: 'REP-401',
    });
    expect(doc.status).toBe('submitted');

    const updated = updateAdmissionDocumentSchema.parse({
      status: 'verified',
    });
    expect(updated.status).toBe('verified');
  });
});

