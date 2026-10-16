import { z } from 'zod';

export interface CsvParseResult {
  headers: string[];
  rows: Record<string, string>[];
}

export interface ImportValidationResult<T> {
  rowNumber: number;
  data: T;
  isValid: boolean;
  errors: string[];
}

export interface BulkImportPreviewResult<T = Record<string, unknown>> {
  entity: 'students' | 'staff' | 'classes_sections';
  totalRows: number;
  validCount: number;
  invalidCount: number;
  validRows: ImportValidationResult<T>[];
  invalidRows: ImportValidationResult<Record<string, string>>[];
}

// Student Row Schema
export const studentImportRowSchema = z.object({
  fullName: z.string().trim().min(2, 'Name must be at least 2 characters').max(120),
  rollNumber: z.string().trim().min(1, 'Roll number is required').max(32),
  gender: z.enum(['male', 'female', 'other']).default('other'),
  dateOfBirth: z.string().trim().regex(/^\d{4}-\d{2}-\d{2}$/, 'Date of birth must be YYYY-MM-DD').optional(),
  parentName: z.string().trim().max(120).optional(),
  parentPhone: z.string().trim().regex(/^(\+91[\-\s]?)?[6-9]\d{9}$/, 'Invalid Indian mobile number format').optional().or(z.literal('')),
  parentEmail: z.string().trim().email('Invalid email address').optional().or(z.literal('')),
  address: z.string().trim().max(255).optional(),
  className: z.string().trim().optional(),
  sectionName: z.string().trim().optional(),
});

// Staff Row Schema
export const staffImportRowSchema = z.object({
  fullName: z.string().trim().min(2, 'Name must be at least 2 characters').max(120),
  email: z.string().trim().email('Invalid email format').toLowerCase(),
  phone: z.string().trim().regex(/^(\+91[\-\s]?)?[6-9]\d{9}$/, 'Invalid phone format').optional().or(z.literal('')),
  employeeId: z.string().trim().max(32).optional(),
  role: z.enum(['teacher', 'admin']).default('teacher'),
});

// Class & Section Row Schema
export const classSectionImportRowSchema = z.object({
  className: z.string().trim().min(1, 'Class name is required').max(64),
  sectionName: z.string().trim().min(1, 'Section name is required').max(32),
  gradeOrder: z.preprocess((val) => (val ? Number(val) : undefined), z.number().int().min(1).optional()),
});

export type StudentImportRow = z.infer<typeof studentImportRowSchema>;
export type StaffImportRow = z.infer<typeof staffImportRowSchema>;
export type ClassSectionImportRow = z.infer<typeof classSectionImportRowSchema>;

export class BulkImporter {
  /**
   * Robust CSV parser supporting quotes, commas, semicolons, and carriage returns.
   */
  static parseCsv(csvText: string): CsvParseResult {
    const lines = csvText
      .replace(/\r\n/g, '\n')
      .replace(/\r/g, '\n')
      .split('\n')
      .map((l) => l.trim())
      .filter((l) => l.length > 0);

    if (lines.length === 0) {
      return { headers: [], rows: [] };
    }

    const firstLine = lines[0] ?? '';
    const delimiter = firstLine.includes('\t') ? '\t' : firstLine.includes(';') ? ';' : ',';

    const parseLine = (line: string): string[] => {
      const values: string[] = [];
      let current = '';
      let inQuotes = false;

      for (let i = 0; i < line.length; i++) {
        const char = line[i];
        if (char === '"') {
          if (inQuotes && line[i + 1] === '"') {
            current += '"';
            i++;
          } else {
            inQuotes = !inQuotes;
          }
        } else if (char === delimiter && !inQuotes) {
          values.push(current.trim());
          current = '';
        } else {
          current += char;
        }
      }
      values.push(current.trim());
      return values;
    };

    const rawHeaders = parseLine(firstLine);
    const headers = rawHeaders.map((h) =>
      h.toLowerCase().replace(/[^a-z0-9]/g, '_').replace(/_{2,}/g, '_').replace(/^_|_$/g, '')
    );

    const rows: Record<string, string>[] = [];
    for (let i = 1; i < lines.length; i++) {
      const line = lines[i];
      if (!line) continue;
      const values = parseLine(line);
      const row: Record<string, string> = {};
      headers.forEach((header, index) => {
        row[header] = values[index] ?? '';
      });
      rows.push(row);
    }

    return { headers, rows };
  }

  /**
   * Previews and validates students CSV.
   */
  static previewStudents(csvText: string): BulkImportPreviewResult<StudentImportRow> {
    const { rows } = this.parseCsv(csvText);
    const validRows: ImportValidationResult<StudentImportRow>[] = [];
    const invalidRows: ImportValidationResult<Record<string, string>>[] = [];
    const seenRollNumbers = new Set<string>();

    rows.forEach((row, idx) => {
      const rowNumber = idx + 2; // +1 for header, +1 for 1-based index

      // Header alias normalizations
      const normalized: Record<string, any> = {
        fullName: row['full_name'] || row['name'] || row['student_name'] || row['student'],
        rollNumber: row['roll_number'] || row['roll_no'] || row['rollno'] || row['id'],
        gender: (row['gender'] || 'other').toLowerCase(),
        dateOfBirth: row['date_of_birth'] || row['dob'] || row['birth_date'],
        parentName: row['parent_name'] || row['guardian_name'] || row['father_name'] || row['mother_name'],
        parentPhone: row['parent_phone'] || row['phone'] || row['mobile'] || row['guardian_phone'],
        parentEmail: row['parent_email'] || row['email'] || row['guardian_email'],
        address: row['address'] || row['residence'],
        className: row['class_name'] || row['class'] || row['grade'],
        sectionName: row['section_name'] || row['section'],
      };

      const result = studentImportRowSchema.safeParse(normalized);
      const errors: string[] = [];

      if (!result.success) {
        result.error.issues.forEach((err) => {
          errors.push(`${err.path.join('.')}: ${err.message}`);
        });
      }

      if (normalized.rollNumber) {
        if (seenRollNumbers.has(normalized.rollNumber)) {
          errors.push(`Duplicate roll number "${normalized.rollNumber}" found in CSV.`);
        } else {
          seenRollNumbers.add(normalized.rollNumber);
        }
      }

      if (errors.length === 0 && result.success) {
        validRows.push({
          rowNumber,
          data: result.data,
          isValid: true,
          errors: [],
        });
      } else {
        invalidRows.push({
          rowNumber,
          data: row,
          isValid: false,
          errors,
        });
      }
    });

    return {
      entity: 'students',
      totalRows: rows.length,
      validCount: validRows.length,
      invalidCount: invalidRows.length,
      validRows,
      invalidRows,
    };
  }

  /**
   * Previews and validates staff CSV.
   */
  static previewStaff(csvText: string): BulkImportPreviewResult<StaffImportRow> {
    const { rows } = this.parseCsv(csvText);
    const validRows: ImportValidationResult<StaffImportRow>[] = [];
    const invalidRows: ImportValidationResult<Record<string, string>>[] = [];
    const seenEmails = new Set<string>();

    rows.forEach((row, idx) => {
      const rowNumber = idx + 2;
      const normalized: Record<string, any> = {
        fullName: row['full_name'] || row['name'] || row['teacher_name'] || row['staff_name'],
        email: (row['email'] || row['mail'] || '').toLowerCase().trim(),
        phone: row['phone'] || row['mobile'] || row['contact'],
        employeeId: row['employee_id'] || row['emp_id'] || row['staff_id'],
        role: (row['role'] || 'teacher').toLowerCase(),
      };

      const result = staffImportRowSchema.safeParse(normalized);
      const errors: string[] = [];

      if (!result.success) {
        result.error.issues.forEach((err) => {
          errors.push(`${err.path.join('.')}: ${err.message}`);
        });
      }

      if (normalized.email) {
        if (seenEmails.has(normalized.email)) {
          errors.push(`Duplicate email "${normalized.email}" found in CSV.`);
        } else {
          seenEmails.add(normalized.email);
        }
      }

      if (errors.length === 0 && result.success) {
        validRows.push({
          rowNumber,
          data: result.data,
          isValid: true,
          errors: [],
        });
      } else {
        invalidRows.push({
          rowNumber,
          data: row,
          isValid: false,
          errors,
        });
      }
    });

    return {
      entity: 'staff',
      totalRows: rows.length,
      validCount: validRows.length,
      invalidCount: invalidRows.length,
      validRows,
      invalidRows,
    };
  }

  /**
   * Previews and validates classes & sections CSV.
   */
  static previewClassesSections(csvText: string): BulkImportPreviewResult<ClassSectionImportRow> {
    const { rows } = this.parseCsv(csvText);
    const validRows: ImportValidationResult<ClassSectionImportRow>[] = [];
    const invalidRows: ImportValidationResult<Record<string, string>>[] = [];

    rows.forEach((row, idx) => {
      const rowNumber = idx + 2;
      const normalized: Record<string, any> = {
        className: row['class_name'] || row['class'] || row['grade'],
        sectionName: row['section_name'] || row['section'],
        gradeOrder: row['grade_order'] || row['order'],
      };

      const result = classSectionImportRowSchema.safeParse(normalized);
      const errors: string[] = [];

      if (!result.success) {
        result.error.issues.forEach((err) => {
          errors.push(`${err.path.join('.')}: ${err.message}`);
        });
      }

      if (errors.length === 0 && result.success) {
        validRows.push({
          rowNumber,
          data: result.data,
          isValid: true,
          errors: [],
        });
      } else {
        invalidRows.push({
          rowNumber,
          data: row,
          isValid: false,
          errors,
        });
      }
    });

    return {
      entity: 'classes_sections',
      totalRows: rows.length,
      validCount: validRows.length,
      invalidCount: invalidRows.length,
      validRows,
      invalidRows,
    };
  }
}
