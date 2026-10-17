import { describe, expect, it } from 'vitest';
import {
  createTrustSchema,
  linkSchoolToTrustSchema,
  createCampusTransferSchema,
  updateCampusTransferStatusSchema,
  registerBiometricDeviceSchema,
  deviceHeartbeatSchema,
  ingestBiometricPunchesSchema,
  reconcileBiometricPunchesSchema,
  createCourseOutcomeSchema,
  createExamQuestionSchema,
  generateBlueprintedPaperSchema,
  createAlumniProfileSchema,
  updateAlumniProfileSchema,
  createTranscriptRequestSchema,
  updateTranscriptRequestStatusSchema,
} from '../src/http/validation';
import { createApp } from '../src/index';

describe('Phase 16 — Multi-Campus Federation & Enterprise Biometrics', () => {
  describe('HTTP Validation Schemas', () => {
    it('validates educational trust creation and school link payloads', () => {
      const validTrust = createTrustSchema.safeParse({
        name: 'Delhi Public Education Society',
        code: 'DPES-CENTRAL',
        registrationNumber: 'REG-TRUST-2026-99',
        address: '12 Barakhamba Road, New Delhi',
        contactEmail: 'trustee@dpes.edu.in',
        contactPhone: '+91 11 2345 6789',
      });
      expect(validTrust.success).toBe(true);

      const invalidTrust = createTrustSchema.safeParse({
        name: 'A', // too short
        code: '',
      });
      expect(invalidTrust.success).toBe(false);

      const validLink = linkSchoolToTrustSchema.safeParse({
        trustId: '00000000-0000-4000-8000-000000000001',
        schoolId: '00000000-0000-4000-8000-000000000002',
      });
      expect(validLink.success).toBe(true);
    });

    it('validates inter-campus transfer request and status review payloads', () => {
      const validTransfer = createCampusTransferSchema.safeParse({
        trustId: '00000000-0000-4000-8000-000000000001',
        targetSchoolId: '00000000-0000-4000-8000-000000000002',
        entityType: 'student',
        studentId: '00000000-0000-4000-8000-000000000003',
        targetClassId: '00000000-0000-4000-8000-000000000004',
        reason: 'Parent relocated to South Campus sector',
        transferDate: '2026-11-01',
        remarks: 'All documents verified and fees cleared for term 1',
      });
      expect(validTransfer.success).toBe(true);

      const invalidTransfer = createCampusTransferSchema.safeParse({
        trustId: '00000000-0000-4000-8000-000000000001',
        targetSchoolId: '00000000-0000-4000-8000-000000000002',
        reason: 'No', // min 3 chars
      });
      expect(invalidTransfer.success).toBe(false);

      const validReview = updateCampusTransferStatusSchema.safeParse({
        status: 'approved',
        remarks: 'Approved by Zonal Director',
      });
      expect(validReview.success).toBe(true);
    });

    it('validates biometric device registration and heartbeat payloads', () => {
      const validDevice = registerBiometricDeviceSchema.safeParse({
        name: 'Main Gate Ingress Turnstile #1',
        deviceCode: 'DEV-GT-01',
        deviceType: 'facial_recognition',
        ipAddress: '192.168.10.50',
        macAddress: '00:1A:2B:3C:4D:5E',
        serialNumber: 'ZKT-FR-998822',
        location: 'North Perimeter Main Gate',
        status: 'online',
      });
      expect(validDevice.success).toBe(true);

      const invalidDevice = registerBiometricDeviceSchema.safeParse({
        name: 'D',
        deviceCode: '',
        location: '',
      });
      expect(invalidDevice.success).toBe(false);

      const validHeartbeat = deviceHeartbeatSchema.safeParse({
        status: 'online',
        ipAddress: '192.168.10.50',
      });
      expect(validHeartbeat.success).toBe(true);
    });

    it('validates biometric punch log ingestion and reconciliation payloads', () => {
      const validIngest = ingestBiometricPunchesSchema.safeParse({
        deviceId: '00000000-0000-4000-8000-000000000001',
        punches: [
          {
            cardOrTokenNumber: 'RFID-10042',
            userType: 'student',
            punchTimestamp: '2026-10-17T08:14:22.000Z',
            punchType: 'in',
            rawPayload: '{"scanConfidence": 98.4}',
          },
          {
            cardOrTokenNumber: 'STF-501',
            userType: 'staff',
            punchTimestamp: '2026-10-17T08:20:00.000Z',
            punchType: 'in',
          },
        ],
      });
      expect(validIngest.success).toBe(true);

      const emptyIngest = ingestBiometricPunchesSchema.safeParse({
        deviceId: '00000000-0000-4000-8000-000000000001',
        punches: [],
      });
      expect(emptyIngest.success).toBe(false);

      const validReconcile = reconcileBiometricPunchesSchema.safeParse({
        date: '2026-10-17',
        classId: '00000000-0000-4000-8000-000000000002',
      });
      expect(validReconcile.success).toBe(true);
    });

    it('validates course outcomes and bloom taxonomy question bank payloads', () => {
      const validCO = createCourseOutcomeSchema.safeParse({
        classId: '00000000-0000-4000-8000-000000000001',
        subjectId: '00000000-0000-4000-8000-000000000002',
        code: 'CO1',
        description: 'Understand and apply the laws of thermodynamics in closed cycles',
        targetAttainmentPercent: 75,
      });
      expect(validCO.success).toBe(true);

      const validQuestion = createExamQuestionSchema.safeParse({
        classId: '00000000-0000-4000-8000-000000000001',
        subjectId: '00000000-0000-4000-8000-000000000002',
        courseOutcomeId: '00000000-0000-4000-8000-000000000003',
        questionText: 'Derive Carnot engine efficiency for ideal monatomic gas cycles.',
        questionType: 'long_answer',
        bloomLevel: 'analyze',
        marks: 5,
        rubrics: '2 marks diagram, 2 marks derivation steps, 1 mark final equation',
      });
      expect(validQuestion.success).toBe(true);

      const validBlueprint = generateBlueprintedPaperSchema.safeParse({
        classId: '00000000-0000-4000-8000-000000000001',
        subjectId: '00000000-0000-4000-8000-000000000002',
        totalMarks: 80,
        bloomDistribution: {
          remember: 20,
          understand: 25,
          apply: 25,
          analyze: 20,
          evaluate: 10,
        },
      });
      expect(validBlueprint.success).toBe(true);
    });

    it('validates alumni profiles and credential transcript requests', () => {
      const validAlumni = createAlumniProfileSchema.safeParse({
        fullName: 'Rohan Deshmukh',
        email: 'rohan.deshmukh@alumni.schoolic.edu',
        phone: '+91 98765 11223',
        graduationYear: 2021,
        higherEducation: 'B.Tech Computer Science, IIT Bombay',
        currentOrganization: 'Google India',
        designation: 'Software Engineer III',
        industry: 'Information Technology',
        linkedinUrl: 'https://linkedin.com/in/rohandeshmukh',
        mentorshipAvailable: true,
      });
      expect(validAlumni.success).toBe(true);

      const invalidAlumni = createAlumniProfileSchema.safeParse({
        fullName: '',
        email: 'invalid-email',
        graduationYear: 1800, // out of range
      });
      expect(invalidAlumni.success).toBe(false);

      const validTranscript = createTranscriptRequestSchema.safeParse({
        alumniId: '00000000-0000-4000-8000-000000000001',
        documentType: 'transcript',
        copies: 3,
        deliveryMode: 'digital',
        notes: 'Required for Master program application at CMU',
      });
      expect(validTranscript.success).toBe(true);

      const validStatusUpdate = updateTranscriptRequestStatusSchema.safeParse({
        status: 'ready',
        feePaid: true,
        issuedDocumentKey: 'transcripts/2026/TR-2026-9021.pdf',
        notes: 'Sealed transcript generated with digital institutional signature',
      });
      expect(validStatusUpdate.success).toBe(true);
    });
  });

  describe('Route Security & Role Access Controls', () => {
    const testEnv = {
      DATABASE_URL: 'postgres://dummy:dummy@localhost:5432/dummy',
      APP_ENV: 'test',
    };

    it('rejects unauthenticated requests to federation and biometrics endpoints with 401', async () => {
      const app = createApp();

      const resTrusts = await app.request('/api/v1/admin/federation/trusts', { method: 'GET' }, testEnv);
      expect(resTrusts.status).toBe(401);

      const resTransfers = await app.request('/api/v1/admin/federation/transfers', { method: 'GET' }, testEnv);
      expect(resTransfers.status).toBe(401);

      const resDevices = await app.request('/api/v1/admin/biometrics/devices', { method: 'GET' }, testEnv);
      expect(resDevices.status).toBe(401);

      const resPunches = await app.request('/api/v1/admin/biometrics/punches', { method: 'GET' }, testEnv);
      expect(resPunches.status).toBe(401);

      const resOBE = await app.request('/api/v1/admin/obe/course-outcomes', { method: 'GET' }, testEnv);
      expect(resOBE.status).toBe(401);

      const resAlumni = await app.request('/api/v1/admin/alumni/profiles', { method: 'GET' }, testEnv);
      expect(resAlumni.status).toBe(401);

      const resTranscripts = await app.request('/api/v1/admin/alumni/transcripts', { method: 'GET' }, testEnv);
      expect(resTranscripts.status).toBe(401);
    });
  });
});
