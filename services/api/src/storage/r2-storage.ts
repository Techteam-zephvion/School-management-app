export interface StoredDocumentMetadata {
  fileKey: string;
  fileUrl: string;
  fileName: string;
  fileSize: number;
  mimeType: string;
}

export interface StoredDocumentResult {
  body: ReadableStream | Uint8Array | ArrayBuffer;
  contentType: string;
  contentLength: number;
  fileName: string;
}

// In-memory fallback for local dev or automated test environments lacking R2 binding
const memoryDocumentStore = new Map<string, { data: Uint8Array; contentType: string; fileName: string }>();

export class DocumentStorage {
  constructor(private readonly bucket?: R2Bucket) {}

  /**
   * Generates a tenant-isolated, collision-resistant object key:
   * schools/{schoolId}/admissions/{applicationId}/{documentId}-{sanitizedFilename}
   */
  static buildFileKey(schoolId: string, applicationId: string, documentId: string, fileName: string): string {
    const sanitized = fileName
      .toLowerCase()
      .replace(/[^a-z0-9._-]/g, '_')
      .replace(/_{2,}/g, '_');
    return `schools/${schoolId}/admissions/${applicationId}/${documentId}-${sanitized}`;
  }

  async uploadFile(params: {
    schoolId: string;
    applicationId: string;
    documentId: string;
    fileName: string;
    contentType: string;
    data: ArrayBuffer | Uint8Array;
  }): Promise<StoredDocumentMetadata> {
    const fileKey = DocumentStorage.buildFileKey(
      params.schoolId,
      params.applicationId,
      params.documentId,
      params.fileName,
    );
    const bytes = params.data instanceof Uint8Array ? params.data : new Uint8Array(params.data);
    const fileSize = bytes.byteLength;
    const mimeType = params.contentType || 'application/octet-stream';

    if (this.bucket) {
      await this.bucket.put(fileKey, bytes, {
        httpMetadata: {
          contentType: mimeType,
          contentDisposition: `inline; filename="${params.fileName}"`,
        },
        customMetadata: {
          schoolId: params.schoolId,
          applicationId: params.applicationId,
          documentId: params.documentId,
          fileName: params.fileName,
        },
      });
    } else {
      memoryDocumentStore.set(fileKey, {
        data: bytes,
        contentType: mimeType,
        fileName: params.fileName,
      });
    }

    const fileUrl = `/api/v1/admin/admissions/applications/${params.applicationId}/documents/${params.documentId}/download`;

    return {
      fileKey,
      fileUrl,
      fileName: params.fileName,
      fileSize,
      mimeType,
    };
  }

  async getFile(fileKey: string): Promise<StoredDocumentResult | null> {
    if (this.bucket) {
      const obj = await this.bucket.get(fileKey);
      if (!obj) return null;

      const contentType = obj.httpMetadata?.contentType || 'application/octet-stream';
      const contentLength = obj.size;
      const fileName = obj.customMetadata?.['fileName'] || fileKey.split('/').pop() || 'document';

      return {
        body: obj.body,
        contentType,
        contentLength,
        fileName,
      };
    }

    const item = memoryDocumentStore.get(fileKey);
    if (!item) return null;

    return {
      body: item.data,
      contentType: item.contentType,
      contentLength: item.data.byteLength,
      fileName: item.fileName,
    };
  }

  async deleteFile(fileKey: string): Promise<boolean> {
    if (this.bucket) {
      await this.bucket.delete(fileKey);
      return true;
    }
    return memoryDocumentStore.delete(fileKey);
  }

  static clearMemoryStore(): void {
    memoryDocumentStore.clear();
  }
}
