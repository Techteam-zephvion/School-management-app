import { describe, expect, it } from 'vitest';
import {
  aiAttendanceInsightsSchema,
  createAnnouncementSchema,
  createTeacherMaterialSchema,
  createTimetableEntrySchema,
  saveAttendanceSchema,
  teacherCopilotSchema,
  updateTimetableEntrySchema,
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
