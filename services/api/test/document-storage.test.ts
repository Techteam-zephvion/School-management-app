import { describe, expect, it, beforeEach } from 'vitest';
import { DocumentStorage } from '../src/storage/r2-storage';
import { addAdmissionDocumentSchema, attachAdmissionDocumentFileSchema } from '../src/http/validation';

describe('Phase 9 — Document Storage & R2 Integration', () => {
  beforeEach(() => {
    DocumentStorage.clearMemoryStore();
  });

  it('generates predictable, tenant-isolated object keys', () => {
    const key = DocumentStorage.buildFileKey(
      'school-uuid-1',
      'app-uuid-2',
      'doc-uuid-3',
      'Student Birth Certificate (Final).pdf',
    );
    expect(key).toBe('schools/school-uuid-1/admissions/app-uuid-2/doc-uuid-3-student_birth_certificate_final_.pdf');
  });

  it('validates admission document file attachment schema', () => {
    const valid = attachAdmissionDocumentFileSchema.safeParse({
      fileKey: 'schools/s1/admissions/a1/d1-birth_cert.pdf',
      fileUrl: '/api/v1/admin/admissions/applications/a1/documents/d1/download',
      fileName: 'birth_cert.pdf',
      fileSize: 1048576,
      mimeType: 'application/pdf',
    });
    expect(valid.success).toBe(true);

    const invalid = attachAdmissionDocumentFileSchema.safeParse({
      fileKey: 'short',
      fileUrl: '',
      fileName: '',
      fileSize: -5,
      mimeType: '',
    });
    expect(invalid.success).toBe(false);
  });

  it('uploads, retrieves, and deletes files using DocumentStorage fallback engine', async () => {
    const storage = new DocumentStorage();
    const mockFileContent = new TextEncoder().encode('Dummy PDF content for certificate');

    // 1. Upload
    const uploaded = await storage.uploadFile({
      schoolId: '10000000-0000-4000-8000-000000000001',
      applicationId: '20000000-0000-4000-8000-000000000002',
      documentId: '30000000-0000-4000-8000-000000000003',
      fileName: 'transfer_cert.pdf',
      contentType: 'application/pdf',
      data: mockFileContent,
    });

    expect(uploaded.fileKey).toContain('transfer_cert.pdf');
    expect(uploaded.fileSize).toBe(mockFileContent.byteLength);
    expect(uploaded.mimeType).toBe('application/pdf');
    expect(uploaded.fileUrl).toContain('30000000-0000-4000-8000-000000000003');

    // 2. Retrieve
    const retrieved = await storage.getFile(uploaded.fileKey);
    expect(retrieved).not.toBeNull();
    expect(retrieved!.contentType).toBe('application/pdf');
    expect(retrieved!.contentLength).toBe(mockFileContent.byteLength);

    const text = new TextDecoder().decode(retrieved!.body as Uint8Array);
    expect(text).toBe('Dummy PDF content for certificate');

    // 3. Delete
    const deleted = await storage.deleteFile(uploaded.fileKey);
    expect(deleted).toBe(true);

    const afterDelete = await storage.getFile(uploaded.fileKey);
    expect(afterDelete).toBeNull();
  });
});
