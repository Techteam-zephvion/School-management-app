import { describe, expect, it } from 'vitest';
import {
  createStudentLeaveSchema,
  updateStudentLeaveStatusSchema,
  createStaffLeaveSchema,
  updateStaffLeaveStatusSchema,
  createTransportVehicleSchema,
  createTransportDriverSchema,
  createTransportRouteSchema,
  createTransportStopSchema,
  createTransportAllocationSchema,
  createTransportLogSchema,
  issueCertificateSchema,
  revokeCertificateSchema,
  publicInquirySchema,
  createCalendarEventSchema,
  createPtmScheduleSchema,
  bookPtmSlotSchema,
  updatePtmSlotNotesSchema,
} from '../src/http/validation';
import { createApp } from '../src/index';

describe('Phase 12 — School Operations & Daily Differentiators', () => {
  describe('Student & Staff Leave Validation', () => {
    it('validates student leave application with attachments', () => {
      const valid = createStudentLeaveSchema.safeParse({
        studentId: '00000000-0000-4000-8000-000000000001',
        startDate: '2026-10-20',
        endDate: '2026-10-22',
        reason: 'Viral fever and physician recommended bed rest',
        documentUrl: 'https://storage.schoolic.in/prescriptions/rx-101.pdf',
      });
      expect(valid.success).toBe(true);

      const invalidDate = createStudentLeaveSchema.safeParse({
        studentId: '00000000-0000-4000-8000-000000000001',
        startDate: 'invalid-date',
        endDate: '2026-10-22',
        reason: 'Too short',
      });
      expect(invalidDate.success).toBe(false);
    });

    it('validates student leave status review by class teacher or admin', () => {
      const validApproval = updateStudentLeaveStatusSchema.safeParse({
        status: 'approved',
        reviewerNotes: 'Approved with medical certificate verified.',
      });
      expect(validApproval.success).toBe(true);

      const invalidStatus = updateStudentLeaveStatusSchema.safeParse({
        status: 'draft',
      });
      expect(invalidStatus.success).toBe(false);
    });

    it('validates staff leave application with multiple leave types', () => {
      const casualLeave = createStaffLeaveSchema.safeParse({
        staffId: '00000000-0000-4000-8000-000000000002',
        leaveType: 'casual',
        startDate: '2026-11-02',
        endDate: '2026-11-03',
        reason: 'Attending family wedding ceremony',
      });
      expect(casualLeave.success).toBe(true);

      const sickLeave = createStaffLeaveSchema.safeParse({
        leaveType: 'sick',
        startDate: '2026-11-10',
        endDate: '2026-11-11',
        reason: 'Medical recovery under physician care',
      });
      expect(sickLeave.success).toBe(true);
    });

    it('validates staff leave approval / rejection', () => {
      const rejection = updateStaffLeaveStatusSchema.safeParse({
        status: 'rejected',
        reviewerNotes: 'Clashes with mid-term examination invigilation roster',
      });
      expect(rejection.success).toBe(true);
    });
  });

  describe('School Transport Fleet & Route Validation', () => {
    it('validates vehicle registration with positive capacity', () => {
      const validBus = createTransportVehicleSchema.safeParse({
        vehicleNumber: 'KA-01-AB-1234',
        model: 'Tata Starbus 40-Seater',
        capacity: 40,
        gpsDeviceId: 'GPS-TR-9988',
        insuranceExpiry: '2027-05-30',
        fitnessExpiry: '2027-06-15',
        status: 'active',
      });
      expect(validBus.success).toBe(true);

      const invalidCapacity = createTransportVehicleSchema.safeParse({
        vehicleNumber: 'KA-01-AB-1234',
        capacity: -5,
      });
      expect(invalidCapacity.success).toBe(false);
    });

    it('validates driver registration with Indian phone format', () => {
      const validDriver = createTransportDriverSchema.safeParse({
        fullName: 'Ramachandra Rao',
        phone: '+919876543210',
        licenseNumber: 'DL-KA-05-2015-1234567',
        licenseExpiry: '2028-12-31',
        status: 'active',
      });
      expect(validDriver.success).toBe(true);

      const invalidPhone = createTransportDriverSchema.safeParse({
        fullName: 'Ramachandra Rao',
        phone: '12345',
        licenseNumber: 'DL-01',
      });
      expect(invalidPhone.success).toBe(false);
    });

    it('validates route and stop definitions with HH:mm time formatting', () => {
      const validRoute = createTransportRouteSchema.safeParse({
        routeNumber: 'R-04',
        routeName: 'Indiranagar to School Campus',
        startPoint: 'Indiranagar 100ft Rd',
        endPoint: 'School Main Gate',
      });
      expect(validRoute.success).toBe(true);

      const validStop = createTransportStopSchema.safeParse({
        routeId: '00000000-0000-4000-8000-000000000010',
        stopName: 'Domlur Flyover Junction',
        pickupTime: '07:25',
        dropTime: '15:45',
        stopOrder: 3,
        monthlyFeeAmount: 1800,
        latitude: '12.9609',
        longitude: '77.6387',
      });
      expect(validStop.success).toBe(true);

      const invalidTime = createTransportStopSchema.safeParse({
        routeId: '00000000-0000-4000-8000-000000000010',
        stopName: 'Domlur Junction',
        pickupTime: '7:25 AM', // invalid format
        dropTime: '3:45 PM',
        stopOrder: 1,
      });
      expect(invalidTime.success).toBe(false);
    });

    it('validates student transport allocation and live checkpoint log', () => {
      const validAlloc = createTransportAllocationSchema.safeParse({
        studentId: '00000000-0000-4000-8000-000000000001',
        routeId: '00000000-0000-4000-8000-000000000010',
        stopId: '00000000-0000-4000-8000-000000000020',
        startDate: '2026-10-01',
      });
      expect(validAlloc.success).toBe(true);

      const validLog = createTransportLogSchema.safeParse({
        routeId: '00000000-0000-4000-8000-000000000010',
        date: '2026-10-16',
        tripType: 'pickup',
        status: 'in_transit',
        currentStopId: '00000000-0000-4000-8000-000000000020',
        notes: 'Departed stop on schedule. All 18 students boarded.',
      });
      expect(validLog.success).toBe(true);
    });
  });

  describe('Official Certificates Generator & Verification', () => {
    it('validates certificate issuance for TC, Bonafide, and Conduct', () => {
      const tc = issueCertificateSchema.safeParse({
        studentId: '00000000-0000-4000-8000-000000000001',
        certificateType: 'transfer_certificate',
        issueDate: '2026-10-16',
        metadata: {
          leavingReason: 'Parent transfer to another state',
          conductRemark: 'Exemplary',
          feeCleared: true,
        },
      });
      expect(tc.success).toBe(true);

      const bonafide = issueCertificateSchema.safeParse({
        studentId: '00000000-0000-4000-8000-000000000001',
        certificateType: 'bonafide',
        metadata: {
          purpose: 'Passport Application',
        },
      });
      expect(bonafide.success).toBe(true);

      const conduct = issueCertificateSchema.safeParse({
        studentId: '00000000-0000-4000-8000-000000000001',
        certificateType: 'character_conduct',
      });
      expect(conduct.success).toBe(true);
    });

    it('validates certificate revocation request', () => {
      const revocation = revokeCertificateSchema.safeParse({
        reason: 'Issued with incorrect parent name spelling. Replacement issued.',
      });
      expect(revocation.success).toBe(true);
    });
  });

  describe('Public Inquiry & RTE Quota Ingestion', () => {
    it('validates public admission inquiry with RTE quota category', () => {
      const rteInquiry = publicInquirySchema.safeParse({
        schoolCode: 'SCH-DEMO-01',
        applicantName: 'Ananya Kumari',
        dateOfBirth: '2020-04-15',
        gender: 'female',
        parentName: 'Suresh Kumar',
        parentPhone: '+919876543210',
        parentEmail: 'suresh.kumar@example.com',
        quotaCategory: 'rte',
        casteCategory: 'sc',
        notes: 'Applying under Right to Education (RTE) Section 12(1)(c) 25% quota reservation.',
      });
      expect(rteInquiry.success).toBe(true);
    });

    it('validates public admission inquiry with standard general category', () => {
      const generalInquiry = publicInquirySchema.safeParse({
        schoolCode: 'SCH-DEMO-01',
        applicantName: 'Arjun Verma',
        parentName: 'Kavita Verma',
        parentPhone: '+919123456780',
        quotaCategory: 'general',
      });
      expect(generalInquiry.success).toBe(true);
    });
  });

  describe('Calendar Events & PTM Scheduling', () => {
    it('validates institutional calendar events', () => {
      const holiday = createCalendarEventSchema.safeParse({
        title: 'Deepavali Holidays',
        description: 'School remains closed for Deepavali festivities',
        eventType: 'holiday',
        startDate: '2026-11-01',
        endDate: '2026-11-04',
        isAllDay: true,
        targetAudience: 'all',
      });
      expect(holiday.success).toBe(true);

      const examEvent = createCalendarEventSchema.safeParse({
        title: 'Term-1 Formative Assessments',
        eventType: 'exam',
        startDate: '2026-11-15',
        endDate: '2026-11-20',
        targetAudience: 'students',
      });
      expect(examEvent.success).toBe(true);
    });

    it('validates PTM schedule and automated slot generation parameters', () => {
      const ptm = createPtmScheduleSchema.safeParse({
        title: 'Grade 10 Mid-Term Parent-Teacher Conference',
        eventDate: '2026-10-24',
        startTime: '09:00',
        endTime: '13:00',
        slotDurationMinutes: 15,
      });
      expect(ptm.success).toBe(true);

      const invalidDuration = createPtmScheduleSchema.safeParse({
        title: 'PTM',
        eventDate: '2026-10-24',
        startTime: '09:00',
        endTime: '13:00',
        slotDurationMinutes: 3, // must be at least 5
      });
      expect(invalidDuration.success).toBe(false);
    });

    it('validates parent PTM slot reservation and teacher notes', () => {
      const booking = bookPtmSlotSchema.safeParse({
        slotId: '00000000-0000-4000-8000-000000000099',
        studentId: '00000000-0000-4000-8000-000000000001',
        parentNotes: 'Requesting discussion on Mathematics quadratic equations progress.',
      });
      expect(booking.success).toBe(true);

      const teacherNotes = updatePtmSlotNotesSchema.safeParse({
        teacherNotes: 'Discussed homework consistency and weekly practice schedule with mother.',
        status: 'completed',
      });
      expect(teacherNotes.success).toBe(true);
    });
  });

  describe('Public Unauthenticated Endpoints Routing', () => {
    it('allows access to public certificate verification endpoint without auth token', async () => {
      const app = createApp();
      const res = await app.request('/api/v1/public/certificates/verify/SCH-TC-NONEXISTENT', {
        method: 'GET',
      }, {
        DATABASE_URL: 'postgres://dummy:dummy@localhost:5432/dummy',
        APP_ENV: 'test',
      });

      // Verification endpoint is open to the public without 401 Unauthorized
      expect(res.status).not.toBe(401);
    });

    it('allows access to public school profile endpoint without auth token', async () => {
      const app = createApp();
      const res = await app.request('/api/v1/public/schools/SCH-DEMO-01', {
        method: 'GET',
      }, {
        DATABASE_URL: 'postgres://dummy:dummy@localhost:5432/dummy',
        APP_ENV: 'test',
      });

      expect(res.status).not.toBe(401);
    });
  });
});
