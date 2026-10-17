import { describe, expect, it } from 'vitest';
import {
  createLibraryBookSchema,
  issueLibraryLoanSchema,
  returnLibraryLoanSchema,
  createInventoryItemSchema,
  allocateInventoryItemSchema,
  createInventoryPurchaseRequestSchema,
  reviewInventoryPurchaseRequestSchema,
  upsertStaffSalaryStructureSchema,
  generateMonthlyPayrollSchema,
  markPayrollPaidSchema,
  createHostelRoomSchema,
  allocateHostelBedSchema,
  createVisitorGatePassSchema,
  upsertStudentHealthProfileSchema,
  recordInfirmaryVisitSchema,
} from '../src/http/validation';
import { createApp } from '../src/index';

describe('Phase 15 — Campus Operations Ecosystem', () => {
  describe('HTTP Validation Schemas', () => {
    it('validates library book creation payload', () => {
      const valid = createLibraryBookSchema.safeParse({
        title: 'Concepts of Physics (Vol 1)',
        author: 'H.C. Verma',
        isbn: '978-8177091878',
        publisher: 'Bharati Bhawan',
        publishedYear: 2020,
        category: 'science',
        shelfLocation: 'Shelf PHY-04',
        totalCopies: 5,
      });
      expect(valid.success).toBe(true);

      const invalidTitle = createLibraryBookSchema.safeParse({
        title: '',
        author: 'Author',
        shelfLocation: 'Shelf 1',
      });
      expect(invalidTitle.success).toBe(false);

      const invalidCategory = createLibraryBookSchema.safeParse({
        title: 'Book',
        author: 'Author',
        shelfLocation: 'Shelf 1',
        category: 'sci_fi', // invalid enum
      });
      expect(invalidCategory.success).toBe(false);
    });

    it('validates library book loan issue and return payloads', () => {
      const validIssue = issueLibraryLoanSchema.safeParse({
        bookId: '00000000-0000-4000-8000-000000000001',
        memberType: 'student',
        memberId: '00000000-0000-4000-8000-000000000002',
        dueDate: '2026-11-01',
        notes: 'Standard 14-day checkout',
      });
      expect(validIssue.success).toBe(true);

      const invalidMember = issueLibraryLoanSchema.safeParse({
        bookId: '00000000-0000-4000-8000-000000000001',
        memberType: 'alumni', // only student or staff
        memberId: '00000000-0000-4000-8000-000000000002',
        dueDate: '2026-11-01',
      });
      expect(invalidMember.success).toBe(false);

      const validReturn = returnLibraryLoanSchema.safeParse({
        returnedAt: '2026-11-02',
        fineAmount: 5000, // 50 INR in paise
        finePaid: true,
        status: 'returned',
      });
      expect(validReturn.success).toBe(true);
    });

    it('validates inventory item creation and staff allocation payloads', () => {
      const validItem = createInventoryItemSchema.safeParse({
        itemCode: 'LAB-MIC-01',
        name: 'Compound Optical Microscope 1000x',
        category: 'lab_equipment',
        quantity: 12,
        unit: 'units',
        condition: 'good',
        roomLocation: 'Biology Lab 102',
        purchaseCost: 1500000, // in paise (₹15,000)
        purchaseDate: '2026-06-15',
      });
      expect(validItem.success).toBe(true);

      const validAllocation = allocateInventoryItemSchema.safeParse({
        allocatedToStaffId: '00000000-0000-4000-8000-000000000001',
        purpose: 'Semester Practical Demonstrations',
        quantity: 4,
        allocatedAt: '2026-10-15',
      });
      expect(validAllocation.success).toBe(true);

      const invalidQuantity = allocateInventoryItemSchema.safeParse({
        allocatedToStaffId: '00000000-0000-4000-8000-000000000001',
        purpose: 'Class',
        quantity: 0, // min 1
      });
      expect(invalidQuantity.success).toBe(false);
    });

    it('validates inventory purchase requisitions', () => {
      const validReq = createInventoryPurchaseRequestSchema.safeParse({
        itemName: 'Football Size 5 (FIFA Approved)',
        category: 'sports_gear',
        quantity: 10,
        estimatedCost: 1800000, // ₹18,000
      });
      expect(validReq.success).toBe(true);

      const validReview = reviewInventoryPurchaseRequestSchema.safeParse({
        status: 'approved',
        reviewNotes: 'Approved for annual sports day budget.',
      });
      expect(validReview.success).toBe(true);
    });

    it('validates staff salary structure and monthly payroll generation', () => {
      const validSalary = upsertStaffSalaryStructureSchema.safeParse({
        staffId: '00000000-0000-4000-8000-000000000001',
        basicSalary: 4500000, // ₹45,000
        hra: 1800000, // ₹18,000
        allowances: 700000, // ₹7,000
        pfDeduction: 540000, // ₹5,400
        esiDeduction: 0,
        tdsDeduction: 350000, // ₹3,500
        effectiveFrom: '2026-04-01',
      });
      expect(validSalary.success).toBe(true);

      const validMonthlyRun = generateMonthlyPayrollSchema.safeParse({
        month: 10,
        year: 2026,
      });
      expect(validMonthlyRun.success).toBe(true);

      const invalidMonth = generateMonthlyPayrollSchema.safeParse({
        month: 13,
        year: 2026,
      });
      expect(invalidMonth.success).toBe(false);

      const validMarkPaid = markPayrollPaidSchema.safeParse({
        paidOn: '2026-10-31',
        paymentReference: 'NEFT-AXIS-99281726',
        notes: 'Monthly salary credited directly to salary account',
      });
      expect(validMarkPaid.success).toBe(true);
    });

    it('validates hostel room creation and bed allocation payloads', () => {
      const validRoom = createHostelRoomSchema.safeParse({
        blockName: 'Vivekananda Block',
        roomNumber: '204',
        roomType: 'boys',
        capacity: 3,
        termFee: 2500000, // ₹25,000 per term
      });
      expect(validRoom.success).toBe(true);

      const validAlloc = allocateHostelBedSchema.safeParse({
        studentId: '00000000-0000-4000-8000-000000000001',
        roomId: '00000000-0000-4000-8000-000000000002',
        bedNumber: 'Bed-B',
        allocatedAt: '2026-07-01',
      });
      expect(validAlloc.success).toBe(true);
    });

    it('validates visitor gate pass issuance payload', () => {
      const validPass = createVisitorGatePassSchema.safeParse({
        visitorName: 'Rajesh Sharma',
        phone: '+91 98765 43210',
        purpose: 'Meeting Principal regarding admission inquiry',
        personToVisitType: 'admin',
        badgeNumber: 'VIS-089',
        vehicleNumber: 'KA-01-AB-1234',
      });
      expect(validPass.success).toBe(true);

      const invalidVisitor = createVisitorGatePassSchema.safeParse({
        visitorName: '',
        phone: '123',
        purpose: '',
        personToVisitType: 'unknown',
        badgeNumber: '',
      });
      expect(invalidVisitor.success).toBe(false);
    });

    it('validates student health profiles and infirmary visit logs', () => {
      const validHealth = upsertStudentHealthProfileSchema.safeParse({
        studentId: '00000000-0000-4000-8000-000000000001',
        bloodGroup: 'B+',
        allergies: 'Peanuts, Penicillin',
        chronicConditions: 'Mild Asthmatic, carries inhaler',
        emergencyContactName: 'Dr. Sunita Verma',
        emergencyContactPhone: '+91 99887 76655',
        doctorNotes: 'Fit for all sports with precautions for dusty environments.',
      });
      expect(validHealth.success).toBe(true);

      const validVisit = recordInfirmaryVisitSchema.safeParse({
        studentId: '00000000-0000-4000-8000-000000000001',
        symptoms: 'Mild fever (99.8 F) and seasonal headache',
        treatmentGiven: 'Administered paracetamol 500mg, cold compress, rested for 45 mins',
        parentNotified: true,
        followUpNeeded: false,
        notes: 'Temperature returned to normal, sent back to 6th period class',
      });
      expect(validVisit.success).toBe(true);
    });
  });

  describe('Route Security & Role Access Controls', () => {
    const testEnv = {
      DATABASE_URL: 'postgres://dummy:dummy@localhost:5432/dummy',
      APP_ENV: 'test',
    };

    it('rejects unauthenticated requests to campus operations endpoints with 401', async () => {
      const app = createApp();
      const res = await app.request('/api/v1/admin/operations/library/books', { method: 'GET' }, testEnv);
      expect(res.status).toBe(401);

      const resPayroll = await app.request('/api/v1/admin/operations/payroll/records', { method: 'GET' }, testEnv);
      expect(resPayroll.status).toBe(401);

      const resHostel = await app.request('/api/v1/admin/operations/hostel/rooms', { method: 'GET' }, testEnv);
      expect(resHostel.status).toBe(401);
    });
  });
});
