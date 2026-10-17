import { describe, expect, it } from 'vitest';
import {
  evaluateStudentRiskSchema,
  recordStudentInterventionSchema,
  naturalLanguageQuerySchema,
  draftReportCardRemarksSchema,
  draftHomeworkFeedbackSchema,
} from '../src/http/validation';
import { createApp } from '../src/index';
import { createSchoolRepository } from '../src/repositories/school-repository';

describe('Phase 14 — Applied AI & Enhanced Institutional UX', () => {
  describe('HTTP Validation Schemas', () => {
    it('validates student risk evaluation filter payload', () => {
      const valid = evaluateStudentRiskSchema.safeParse({
        academicYearId: '00000000-0000-4000-8000-000000000001',
        classId: '00000000-0000-4000-8000-000000000002',
        sectionId: '00000000-0000-4000-8000-000000000003',
      });
      expect(valid.success).toBe(true);

      const empty = evaluateStudentRiskSchema.safeParse({});
      expect(empty.success).toBe(true);

      const invalid = evaluateStudentRiskSchema.safeParse({
        classId: 'not-a-uuid',
      });
      expect(invalid.success).toBe(false);
    });

    it('validates teacher/counselor intervention logging payload', () => {
      const valid = recordStudentInterventionSchema.safeParse({
        action: 'Parent-Teacher Meeting Conducted',
        notes: 'Met with father to address attendance slump. Father agreed to monitor morning routine.',
        status: 'acknowledged',
      });
      expect(valid.success).toBe(true);

      const invalidAction = recordStudentInterventionSchema.safeParse({
        action: 'A', // min 2
        notes: 'Valid note',
      });
      expect(invalidAction.success).toBe(false);

      const invalidStatus = recordStudentInterventionSchema.safeParse({
        action: 'Valid Action',
        notes: 'Valid note',
        status: 'invalid_status',
      });
      expect(invalidStatus.success).toBe(false);
    });

    it('validates natural language query input', () => {
      const validQuery = naturalLanguageQuerySchema.safeParse({
        query: 'Show me fee defaulters with balance exceeding 10000',
      });
      expect(validQuery.success).toBe(true);

      const tooShort = naturalLanguageQuerySchema.safeParse({
        query: 'a',
      });
      expect(tooShort.success).toBe(false);
    });

    it('validates report card remark drafting parameters', () => {
      const valid = draftReportCardRemarksSchema.safeParse({
        studentName: 'Aarav Patel',
        overallPercentage: '88.5%',
        attendanceRate: '94%',
        tone: 'encouraging',
        subjects: [
          { subjectName: 'Mathematics', grade: 'A1', marksObtained: 95, maxMarks: 100 },
          { subjectName: 'Science', grade: 'A2', marksObtained: 86, maxMarks: 100 },
        ],
        coScholastic: [
          { domain: 'Work Education', grade: 'A' },
          { domain: 'Discipline', grade: 'A' },
        ],
      });
      expect(valid.success).toBe(true);

      const invalidTone = draftReportCardRemarksSchema.safeParse({
        studentName: 'Aarav Patel',
        overallPercentage: '88.5%',
        tone: 'super_happy',
      });
      expect(invalidTone.success).toBe(false);
    });

    it('validates homework submission feedback drafting parameters', () => {
      const valid = draftHomeworkFeedbackSchema.safeParse({
        assignmentTitle: 'Photosynthesis Lab Worksheet',
        subject: 'Science',
        studentScore: 18,
        maxScore: 20,
        strengths: 'Excellent diagrams and correct chemical equation.',
        areasForImprovement: 'Include label on stroma in chloroplast diagram.',
      });
      expect(valid.success).toBe(true);

      const invalidScore = draftHomeworkFeedbackSchema.safeParse({
        assignmentTitle: 'Assignment 1',
        subject: 'Math',
        studentScore: -5,
        maxScore: 20,
      });
      expect(invalidScore.success).toBe(false);
    });
  });

  describe('AI Teacher Drafting Helpers', () => {
    it('drafts personalized pedagogical report card remarks across multiple tones', () => {
      const repo = createSchoolRepository({} as any);

      const encouraging = repo.draftReportCardRemarks({
        studentName: 'Sneha Rao',
        overallPercentage: '92.4%',
        attendanceRate: '96%',
        tone: 'encouraging',
        subjects: [
          { subjectName: 'Mathematics', grade: 'A1', marksObtained: 98, maxMarks: 100 },
          { subjectName: 'English', grade: 'A2', marksObtained: 89, maxMarks: 100 },
        ],
      });

      expect(encouraging.studentName).toBe('Sneha Rao');
      expect(encouraging.tone).toBe('encouraging');
      expect(encouraging.draftRemarks).toContain('Sneha');
      expect(encouraging.draftRemarks).toContain('92.4%');
      expect(encouraging.alternativeOptions.length).toBeGreaterThan(0);

      const constructive = repo.draftReportCardRemarks({
        studentName: 'Rohan Sharma',
        overallPercentage: '48.0%',
        attendanceRate: '71%',
        tone: 'constructive',
        subjects: [
          { subjectName: 'Mathematics', grade: 'D', marksObtained: 38, maxMarks: 100 },
        ],
      });

      expect(constructive.tone).toBe('constructive');
      expect(constructive.draftRemarks).toContain('Rohan');
      expect(constructive.alternativeOptions.length).toBeGreaterThan(0);
    });

    it('drafts formative homework feedback with rubric analysis', () => {
      const repo = createSchoolRepository({} as any);

      const feedback = repo.draftHomeworkFeedback({
        assignmentTitle: 'Quadratic Equations Exercise 4.2',
        subject: 'Mathematics',
        studentScore: 17,
        maxScore: 20,
        strengths: 'Clean step-by-step factorization shown.',
        areasForImprovement: 'Check signs when transposing terms.',
      });

      expect(feedback.scorePercentage).toBe('85%');
      expect(feedback.rubricGrade).toContain('Proficient');
      expect(feedback.feedbackText).toContain('Quadratic Equations Exercise 4.2');
      expect(feedback.feedbackText).toContain('factorization');
    });
  });

  describe('Security & Role Access Controls for Phase 14', () => {
    const env: any = {
      APP_ENV: 'test',
      DATABASE_URL: 'postgres://test:test@localhost:5432/schoolic',
      CORS_ORIGIN: '*',
      NEON_AUTH_URL: 'https://auth.neon.tech',
    };

    const app = createApp();

    it('rejects unauthorized access to admin at-risk analytics without token', async () => {
      const res = await app.request('/api/v1/admin/analytics/at-risk-students', {
        method: 'GET',
      }, env);
      expect(res.status).toBe(401);
    });

    it('rejects unauthorized access to natural language analytics query without token', async () => {
      const res = await app.request('/api/v1/admin/analytics/natural-language-query', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ query: 'List fee defaulters' }),
      }, env);
      expect(res.status).toBe(401);
    });

    it('rejects unauthorized access to teacher AI drafting endpoints', async () => {
      const res = await app.request('/api/v1/teacher/ai/draft-remarks', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          studentName: 'Test Student',
          overallPercentage: '85%',
        }),
      }, env);
      expect(res.status).toBe(401);
    });
  });
});
