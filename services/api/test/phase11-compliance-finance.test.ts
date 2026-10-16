import { describe, expect, it } from 'vitest';
import { calculateLateFee } from '../src/repositories/school-repository';
import {
  recordConsentSchema,
  createDsrRequestSchema,
  resolveDsrRequestSchema,
  createFeeConcessionSchema,
  createFeeRefundSchema,
  createFeeStructureHeadSchema,
} from '../src/http/validation';

describe('Phase 11 — Enterprise RBAC, DPDP Compliance & Financial Depth', () => {
  describe('Late Fee Policy Engine', () => {
    it('returns zero late fee when current date is within grace period', () => {
      const now = new Date('2026-10-15T10:00:00Z');
      const res = calculateLateFee(
        '2026-10-12',
        10000,
        {
          lateFeeGracePeriodDays: 5,
          lateFeeType: 'flat',
          lateFeeAmount: 500,
        },
        now,
      );

      expect(res.isOverdue).toBe(true);
      expect(res.lateFee).toBe(0);
      expect(res.totalDue).toBe(10000);
      expect(res.daysLate).toBe(0);
    });

    it('calculates flat late fee once grace period has elapsed', () => {
      const now = new Date('2026-10-25T10:00:00Z');
      const res = calculateLateFee(
        '2026-10-10',
        10000,
        {
          lateFeeGracePeriodDays: 5,
          lateFeeType: 'flat',
          lateFeeAmount: 500,
        },
        now,
      );

      expect(res.isOverdue).toBe(true);
      expect(res.lateFee).toBe(500);
      expect(res.totalDue).toBe(10500);
      expect(res.daysLate).toBeGreaterThanOrEqual(10);
    });

    it('calculates per-day cumulative late fee after grace period', () => {
      // Due Oct 1, grace 4 days (grace ends Oct 5). Check Oct 10 -> 5 days late
      const now = new Date('2026-10-10T00:00:00Z');
      const res = calculateLateFee(
        '2026-10-01',
        5000,
        {
          lateFeeGracePeriodDays: 4,
          lateFeeType: 'daily',
          lateFeeAmount: 50,
        },
        now,
      );

      expect(res.isOverdue).toBe(true);
      expect(res.daysLate).toBe(5);
      expect(res.lateFee).toBe(250); // 5 * 50
      expect(res.totalDue).toBe(5250);
    });

    it('returns original amount when late fee type is none', () => {
      const now = new Date('2026-11-01T00:00:00Z');
      const res = calculateLateFee(
        '2026-10-01',
        7500,
        {
          lateFeeGracePeriodDays: 0,
          lateFeeType: 'none',
          lateFeeAmount: 0,
        },
        now,
      );

      expect(res.lateFee).toBe(0);
      expect(res.totalDue).toBe(7500);
    });
  });

  describe('DPDP Act 2023 Validation Schemas', () => {
    it('validates parental consent record input with phone format', () => {
      const valid = recordConsentSchema.safeParse({
        studentId: '00000000-0000-4000-8000-000000000001',
        parentGuardianName: 'Rajesh Sharma',
        parentGuardianPhone: '+919876543210',
        consentType: 'enrollment_data_processing',
        verifiedVia: 'portal_submission',
        validUntil: '2027-03-31',
      });

      expect(valid.success).toBe(true);
    });

    it('rejects invalid parental consent without required studentId', () => {
      const invalid = recordConsentSchema.safeParse({
        parentGuardianName: 'Rajesh Sharma',
        parentGuardianPhone: '12345',
        consentType: 'media_publication',
      });

      expect(invalid.success).toBe(false);
    });

    it('validates DSR request types (data_access, data_rectification, data_erasure_anonymization)', () => {
      const validAccess = createDsrRequestSchema.safeParse({
        requestType: 'data_access',
        reason: 'Parent request to download comprehensive attendance and marks transcript under DPDP 2023.',
      });
      expect(validAccess.success).toBe(true);

      const validErasure = createDsrRequestSchema.safeParse({
        studentId: '00000000-0000-4000-8000-000000000002',
        requestType: 'data_erasure_anonymization',
        reason: 'Student graduated and transferred to university. Requested PII erasure.',
      });
      expect(validErasure.success).toBe(true);

      const invalidType = createDsrRequestSchema.safeParse({
        requestType: 'invalid_type',
        reason: 'Test reason with sufficient length.',
      });
      expect(invalidType.success).toBe(false);
    });

    it('validates DSR resolution payload', () => {
      const valid = resolveDsrRequestSchema.safeParse({
        status: 'fulfilled',
        resolutionNotes: 'PII redacted and student record anonymized per DPDP compliance policy.',
        anonymizeStudent: true,
      });

      expect(valid.success).toBe(true);
      if (valid.success) {
        expect(valid.data.anonymizeStudent).toBe(true);
      }
    });
  });

  describe('Financial Depth & Concession Schemas', () => {
    it('validates fee concession creation', () => {
      const percentageConcession = createFeeConcessionSchema.safeParse({
        name: 'Sibling Discount 15%',
        code: 'SIBLING15',
        type: 'percentage',
        value: 15,
        category: 'sibling',
      });
      expect(percentageConcession.success).toBe(true);

      const flatConcession = createFeeConcessionSchema.safeParse({
        name: 'Staff Ward Waiver',
        code: 'STAFF1000',
        type: 'flat',
        value: 10000,
        category: 'staff_ward',
      });
      expect(flatConcession.success).toBe(true);
    });

    it('validates fee refund creation and modes', () => {
      const validRefund = createFeeRefundSchema.safeParse({
        allocationId: '00000000-0000-4000-8000-000000000001',
        studentId: '00000000-0000-4000-8000-000000000002',
        amount: 2500,
        reason: 'Double payment made via UPI and Cash counter.',
        mode: 'bank_transfer',
        referenceNumber: 'UTR-9876543210',
      });
      expect(validRefund.success).toBe(true);

      const invalidAmount = createFeeRefundSchema.safeParse({
        allocationId: '00000000-0000-4000-8000-000000000001',
        studentId: '00000000-0000-4000-8000-000000000002',
        amount: -100,
        reason: 'Invalid negative refund',
      });
      expect(invalidAmount.success).toBe(false);
    });

    it('validates fee structure heads (Tuition, Transport, Uniform, Lab, Examination)', () => {
      const tuitionHead = createFeeStructureHeadSchema.safeParse({
        feeStructureId: '00000000-0000-4000-8000-000000000001',
        headName: 'Tuition',
        amount: 35000,
        isOptional: false,
      });
      expect(tuitionHead.success).toBe(true);

      const transportHead = createFeeStructureHeadSchema.safeParse({
        feeStructureId: '00000000-0000-4000-8000-000000000001',
        headName: 'Transport Route 4A',
        amount: 8000,
        isOptional: true,
      });
      expect(transportHead.success).toBe(true);
    });
  });
});
