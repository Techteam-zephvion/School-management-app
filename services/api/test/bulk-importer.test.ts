import { describe, expect, it } from 'vitest';
import { BulkImporter } from '../src/importers/bulk-importer';
import {
  bulkImportPreviewSchema,
  bulkImportCommitSchema,
  onboardingWizardSchema,
} from '../src/http/validation';

describe('BulkImporter', () => {
  describe('parseCsv', () => {
    it('parses standard comma-separated CSV with headers', () => {
      const csv = `Full Name, Roll Number, Gender\nAarav Sharma, 101, male\nDiya Patel, 102, female`;
      const result = BulkImporter.parseCsv(csv);

      expect(result.headers).toEqual(['full_name', 'roll_number', 'gender']);
      expect(result.rows).toHaveLength(2);
      expect(result.rows[0]).toEqual({
        full_name: 'Aarav Sharma',
        roll_number: '101',
        gender: 'male',
      });
      expect(result.rows[1]).toEqual({
        full_name: 'Diya Patel',
        roll_number: '102',
        gender: 'female',
      });
    });

    it('handles quoted values with commas and escaped quotes', () => {
      const csv = `Name,Address,Notes\n"Rohan, Kumar","123 MG Road, Bengaluru","Said ""Hello"""`;
      const result = BulkImporter.parseCsv(csv);

      expect(result.rows).toHaveLength(1);
      expect(result.rows[0]?.['name']).toBe('Rohan, Kumar');
      expect(result.rows[0]?.['address']).toBe('123 MG Road, Bengaluru');
      expect(result.rows[0]?.['notes']).toBe('Said "Hello"');
    });

    it('handles semicolon delimited CSV', () => {
      const csv = `Name;Roll;Gender\nAnanya;201;female`;
      const result = BulkImporter.parseCsv(csv);

      expect(result.headers).toEqual(['name', 'roll', 'gender']);
      expect(result.rows).toHaveLength(1);
      expect(result.rows[0]?.['name']).toBe('Ananya');
      expect(result.rows[0]?.['roll']).toBe('201');
    });
  });

  describe('previewStudents', () => {
    it('validates correct student rows and captures data', () => {
      const csv = `Name, Roll Number, Gender, Parent Name, Parent Phone, Parent Email, Class, Section
Aarav Sharma, R-101, male, Rajesh Sharma, +919876543210, rajesh@example.com, Grade 10, A
Diya Patel, R-102, female, Sunita Patel, 9876543211, sunita@example.com, Grade 10, A`;

      const preview = BulkImporter.previewStudents(csv);

      expect(preview.entity).toBe('students');
      expect(preview.totalRows).toBe(2);
      expect(preview.validCount).toBe(2);
      expect(preview.invalidCount).toBe(0);
      expect(preview.validRows[0]?.data.fullName).toBe('Aarav Sharma');
      expect(preview.validRows[0]?.data.rollNumber).toBe('R-101');
      expect(preview.validRows[1]?.data.fullName).toBe('Diya Patel');
    });

    it('detects duplicate roll numbers in CSV and invalid phone format', () => {
      const csv = `Name, Roll No, Gender, Mobile
Aarav Sharma, R-101, male, 9876543210
Duplicate Aarav, R-101, male, 9876543210
Invalid Phone, R-103, other, 12345`;

      const preview = BulkImporter.previewStudents(csv);

      expect(preview.totalRows).toBe(3);
      expect(preview.validCount).toBe(1);
      expect(preview.invalidCount).toBe(2);

      // Row 2 has duplicate roll number
      const duplicateRow = preview.invalidRows.find((r) => r.rowNumber === 3);
      expect(duplicateRow).toBeDefined();
      expect(duplicateRow?.errors.some((e) => e.includes('Duplicate roll number'))).toBe(true);

      // Row 3 has invalid phone number
      const invalidPhoneRow = preview.invalidRows.find((r) => r.rowNumber === 4);
      expect(invalidPhoneRow).toBeDefined();
      expect(invalidPhoneRow?.errors.some((e) => e.includes('parentPhone'))).toBe(true);
    });
  });

  describe('previewStaff', () => {
    it('validates staff rows and checks for duplicate emails', () => {
      const csv = `Full Name, Email, Phone, Employee ID, Role
Priya Sen, priya.sen@school.edu, 9876543210, EMP-001, teacher
Amit Verma, priya.sen@school.edu, 9876543211, EMP-002, admin`;

      const preview = BulkImporter.previewStaff(csv);

      expect(preview.totalRows).toBe(2);
      expect(preview.validCount).toBe(1);
      expect(preview.invalidCount).toBe(1);
      expect(preview.invalidRows[0]?.errors.some((e) => e.includes('Duplicate email'))).toBe(true);
    });
  });

  describe('previewClassesSections', () => {
    it('validates class and section rows', () => {
      const csv = `Class, Section, Grade Order
Class 1, Section A, 1
Class 1, Section B, 1
Class 2, Section A, 2`;

      const preview = BulkImporter.previewClassesSections(csv);

      expect(preview.totalRows).toBe(3);
      expect(preview.validCount).toBe(3);
      expect(preview.invalidCount).toBe(0);
      expect(preview.validRows[0]?.data.className).toBe('Class 1');
      expect(preview.validRows[0]?.data.sectionName).toBe('Section A');
      expect(preview.validRows[0]?.data.gradeOrder).toBe(1);
    });
  });
});

describe('Phase 10 Validation Schemas', () => {
  it('validates bulkImportPreviewSchema', () => {
    const valid = bulkImportPreviewSchema.safeParse({
      entity: 'students',
      csv: 'name,roll\nA,1',
    });
    expect(valid.success).toBe(true);

    const invalid = bulkImportPreviewSchema.safeParse({
      entity: 'invalid_entity',
      csv: '',
    });
    expect(invalid.success).toBe(false);
  });

  it('validates onboardingWizardSchema', () => {
    const valid = onboardingWizardSchema.safeParse({
      schoolName: 'Delhi Public International School',
      academicYearName: 'Academic Year 2026-27',
      startDate: '2026-04-01',
      endDate: '2027-03-31',
      classes: [
        { name: 'Grade 9', sections: ['A', 'B'] },
        { name: 'Grade 10', sections: ['A', 'B', 'C'] },
      ],
    });
    expect(valid.success).toBe(true);

    const invalidDate = onboardingWizardSchema.safeParse({
      schoolName: 'Test School',
      academicYearName: 'AY 2026',
      startDate: 'invalid-date',
      endDate: '2027-03-31',
      classes: [],
    });
    expect(invalidDate.success).toBe(false);
  });
});
