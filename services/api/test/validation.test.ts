import { describe, expect, it } from 'vitest';
import { saveAttendanceSchema } from '../src/http/validation';

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
