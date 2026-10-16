import { describe, expect, it } from 'vitest';
import {
  createGradingSchemeSchema,
  createGradingScaleSchema,
  createEvaluationComponentSchema,
  generateReportCardsSchema,
  publishReportCardSchema,
  syncOfflineAttendanceSchema,
} from '../src/http/validation';
import { createApp } from '../src/index';

describe('Phase 13 — Academic Depth, Regional Languages & Offline App', () => {
  describe('Board-Specific Grading Schemes Validation', () => {
    it('validates CBSE, ICSE, and State Board grading scheme creation', () => {
      const cbse = createGradingSchemeSchema.safeParse({
        name: 'CBSE Secondary Evaluation 2026-27',
        board: 'cbse',
        passingPercentage: 33,
        description: 'Standard 9-point scale with CCE components',
        isDefault: true,
      });
      expect(cbse.success).toBe(true);

      const icse = createGradingSchemeSchema.safeParse({
        name: 'ICSE Board Framework Class X',
        board: 'icse',
        passingPercentage: 35,
        description: 'Internal project work 20% + External examination 80%',
      });
      expect(icse.success).toBe(true);

      const stateBoard = createGradingSchemeSchema.safeParse({
        name: 'Karnataka State Board CCE Scheme',
        board: 'state_board',
        passingPercentage: 35,
        description: 'FA1-FA4 (40%) and SA1-SA2 (60%)',
      });
      expect(stateBoard.success).toBe(true);

      const invalidBoard = createGradingSchemeSchema.safeParse({
        name: 'Invalid Board',
        board: 'non_existent_board',
      });
      expect(invalidBoard.success).toBe(false);
    });

    it('validates grading scale entries with percentage boundaries and grade points', () => {
      const a1Scale = createGradingScaleSchema.safeParse({
        schemeId: '00000000-0000-4000-8000-000000000001',
        grade: 'A1',
        minScore: 91,
        maxScore: 100,
        gradePoint: '10.0',
        remarks: 'Outstanding performance',
        orderIndex: 0,
      });
      expect(a1Scale.success).toBe(true);

      const invalidRange = createGradingScaleSchema.safeParse({
        schemeId: '00000000-0000-4000-8000-000000000001',
        grade: 'A1',
        minScore: -5,
        maxScore: 120,
        gradePoint: '10.0',
      });
      expect(invalidRange.success).toBe(false);
    });

    it('validates evaluation components with weightages and assessment types', () => {
      const periodicTest = createEvaluationComponentSchema.safeParse({
        schemeId: '00000000-0000-4000-8000-000000000001',
        name: 'Periodic Test 1',
        componentType: 'periodic_test',
        term: 'term_1',
        weightagePercentage: 10,
        maxMarks: 20,
        orderIndex: 1,
      });
      expect(periodicTest.success).toBe(true);

      const annualExam = createEvaluationComponentSchema.safeParse({
        schemeId: '00000000-0000-4000-8000-000000000001',
        name: 'Annual Board Exam',
        componentType: 'term_exam',
        term: 'annual',
        weightagePercentage: 80,
        maxMarks: 80,
        orderIndex: 2,
      });
      expect(annualExam.success).toBe(true);
    });
  });

  describe('Report Card Generation & Publishing Validation', () => {
    it('validates bulk report card generation payload', () => {
      const valid = generateReportCardsSchema.safeParse({
        academicYearId: '00000000-0000-4000-8000-000000000001',
        classId: '00000000-0000-4000-8000-000000000002',
        sectionId: '00000000-0000-4000-8000-000000000003',
        schemeId: '00000000-0000-4000-8000-000000000004',
        term: 'annual',
        teacherRemarks: 'Excellent academic progress throughout the year.',
      });
      expect(valid.success).toBe(true);

      const missingSection = generateReportCardsSchema.safeParse({
        academicYearId: '00000000-0000-4000-8000-000000000001',
        classId: '00000000-0000-4000-8000-000000000002',
        schemeId: '00000000-0000-4000-8000-000000000004',
      });
      expect(missingSection.success).toBe(false);
    });

    it('validates report card publication status toggle', () => {
      const publish = publishReportCardSchema.safeParse({ isPublished: true });
      expect(publish.success).toBe(true);

      const unpublish = publishReportCardSchema.safeParse({ isPublished: false });
      expect(unpublish.success).toBe(true);
    });
  });

  describe('Offline-First Attendance Synchronization Validation', () => {
    it('validates offline batch attendance sync payload with client timestamps', () => {
      const syncPayload = syncOfflineAttendanceSchema.safeParse({
        batches: [
          {
            clientBatchId: 'batch-local-device-01-20261016-0930',
            academicYearId: '00000000-0000-4000-8000-000000000001',
            classId: '00000000-0000-4000-8000-000000000002',
            sectionId: '00000000-0000-4000-8000-000000000003',
            kind: 'daily',
            attendanceDate: '2026-10-16',
            clientTimestamp: '2026-10-16T09:30:00.000Z',
            records: [
              {
                studentId: '00000000-0000-4000-8000-000000000010',
                status: 'present',
              },
              {
                studentId: '00000000-0000-4000-8000-000000000011',
                status: 'absent',
                remarks: 'Unwell',
              },
              {
                studentId: '00000000-0000-4000-8000-000000000012',
                status: 'late',
                remarks: 'School bus delayed',
              },
            ],
          },
        ],
      });
      expect(syncPayload.success).toBe(true);

      const emptyBatches = syncOfflineAttendanceSchema.safeParse({
        batches: [],
      });
      expect(emptyBatches.success).toBe(false);
    });
  });

  describe('Phase 13 Endpoints Authentication & Routing', () => {
    const env: any = {
      APP_ENV: 'test',
      DATABASE_URL: 'postgres://test:test@localhost:5432/schoolic',
      CORS_ORIGIN: '*',
      NEON_AUTH_URL: 'https://auth.neon.tech',
    };

    it('rejects unauthenticated requests to admin grading schemes', async () => {
      const app = createApp();
      const res = await app.request('/api/v1/admin/academics/grading-schemes', {
        method: 'GET',
      }, env);
      expect(res.status).toBe(401);
    });

    it('rejects unauthenticated requests to report card generation', async () => {
      const app = createApp();
      const res = await app.request('/api/v1/admin/academics/report-cards/generate', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({}),
      }, env);
      expect(res.status).toBe(401);
    });

    it('rejects unauthenticated requests to teacher offline attendance sync', async () => {
      const app = createApp();
      const res = await app.request('/api/v1/teacher/attendance/sync', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ batches: [] }),
      }, env);
      expect(res.status).toBe(401);
    });

    it('rejects unauthenticated requests to portal board report cards', async () => {
      const app = createApp();
      const res = await app.request('/api/v1/portal/board-report-cards', {
        method: 'GET',
      }, env);
      expect(res.status).toBe(401);
    });
  });
});
