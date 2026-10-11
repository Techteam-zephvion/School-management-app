import { describe, expect, it } from 'vitest';
import { createTimetableEntrySchema, saveAttendanceSchema, updateTimetableEntrySchema } from '../src/http/validation';

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
