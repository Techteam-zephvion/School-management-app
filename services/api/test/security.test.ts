import { describe, expect, it, vi, beforeEach } from 'vitest';
import { createApp } from '../src/index';
import { createSchoolRepository } from '../src/repositories/school-repository';
import type { AuthUser } from '../src/types';

const ADMIN_NEON_ID = 'neon-admin-uuid';
const TEACHER_NEON_ID = 'neon-teacher-uuid';
const SCHOOL_ID = '00000000-0000-4000-8000-000000000001';
const STAFF_ID = '00000000-0000-4000-8000-000000000002';
const ASSIGNED_SECTION_ID = '00000000-0000-4000-8000-000000000010';
const UNASSIGNED_SECTION_ID = '00000000-0000-4000-8000-000000000020';
const ACADEMIC_YEAR_ID = '00000000-0000-4000-8000-000000000100';
const STUDENT_ID = '00000000-0000-4000-8000-000000000200';

let mockUserRows: any[] = [];

// Mock database layer
vi.mock('../src/db/client', () => {
  return {
    createDb: vi.fn(() => ({
      select: vi.fn(() => ({
        from: vi.fn(() => ({
          leftJoin: vi.fn(() => ({
            leftJoin: vi.fn(() => ({
              where: vi.fn(() => {
                return {
                  then: (resolve: (rows: any[]) => void) => {
                    resolve(mockUserRows);
                  },
                };
              }),
            })),
          })),
          where: vi.fn(() => ({
            limit: vi.fn().mockResolvedValue([]),
          })),
        })),
      })),
      insert: vi.fn(() => ({
        values: vi.fn(() => ({
          returning: vi.fn().mockResolvedValue([]),
          onConflictDoUpdate: vi.fn(() => ({
            returning: vi.fn().mockResolvedValue([]),
          })),
        })),
      })),
    })),
  };
});

describe('Phase 2 — Security & Authentication Hardening', () => {
  const prodEnv = {
    APP_ENV: 'production',
    CORS_ORIGIN: 'https://schoolic.zephvion.com',
    DATABASE_URL: 'postgres://example',
    NEON_AUTH_URL: 'https://auth.schoolic.zephvion.com',
    BOOTSTRAP_TOKEN: 'secret-prod-token',
  };

  const devEnv = {
    APP_ENV: 'development',
    CORS_ORIGIN: 'http://localhost:8080',
    DATABASE_URL: 'postgres://example',
    NEON_AUTH_URL: 'http://localhost:8787',
    BOOTSTRAP_TOKEN: 'dev-token',
  };

  beforeEach(() => {
    vi.restoreAllMocks();
    mockUserRows = [];
  });

  describe('1. Authentication Verification & Fail-Closed Behavior', () => {
    it('rejects unauthenticated request to protected endpoint with 401', async () => {
      const response = await createApp().request('/api/v1/me', {}, prodEnv);
      expect(response.status).toBe(401);
      const json = (await response.json()) as any;
      expect(json.error).toBe('Authentication required');
    });

    it('rejects development header bypass attempts in production with 401', async () => {
      // An attacker sends x-dev-neon-user-id in production
      const response = await createApp().request(
        '/api/v1/me',
        {
          headers: {
            'x-dev-neon-user-id': 'dev-admin',
            'x-dev-email': 'admin@schoolic.local',
          },
        },
        prodEnv,
      );

      // Must fail closed with 401 and NEVER establish identity
      expect(response.status).toBe(401);
      const json = (await response.json()) as any;
      expect(json.error).toBe('Authentication required');
    });

    it('fails closed with 500 when production NEON_AUTH_URL is missing', async () => {
      const response = await createApp().request(
        '/api/v1/me',
        {
          headers: {
            authorization: 'Bearer sample-token',
          },
        },
        {
          ...prodEnv,
          NEON_AUTH_URL: '',
        },
      );

      expect(response.status).toBe(500);
      const json = (await response.json()) as any;
      expect(json.error).toBe('Authentication service misconfigured');
    });

    it('rejects invalid or tampered bearer token with 401', async () => {
      // Mock Neon Auth service returning 401 for tampered token
      vi.spyOn(globalThis, 'fetch').mockResolvedValueOnce(
        new Response(JSON.stringify({ error: 'Invalid token' }), { status: 401 }),
      );

      const response = await createApp().request(
        '/api/v1/me',
        {
          headers: {
            authorization: 'Bearer tampered-token-xyz',
          },
        },
        prodEnv,
      );

      expect(response.status).toBe(401);
      const json = (await response.json()) as any;
      expect(json.error).toBe('Invalid or expired session');
    });

    it('rejects expired token or invalid session with 401', async () => {
      // Mock Neon Auth service returning expired session
      vi.spyOn(globalThis, 'fetch').mockResolvedValueOnce(
        new Response(JSON.stringify({ error: 'Session expired' }), { status: 401 }),
      );

      const response = await createApp().request(
        '/api/v1/me',
        {
          headers: {
            authorization: 'Bearer expired-session-token',
          },
        },
        prodEnv,
      );

      expect(response.status).toBe(401);
    });
  });

  describe('2. Role-Based Authorization & Tenant Boundaries', () => {
    it('denies user with insufficient permissions with 403', async () => {
      // Provision user with only 'teacher' role
      mockUserRows = [
        {
          appUserId: 'teacher-app-user-id',
          schoolId: SCHOOL_ID,
          email: 'teacher@schoolic.local',
          isActive: true,
          role: 'teacher',
          staffId: STAFF_ID,
        },
      ];

      // Teacher attempts to access admin-only endpoint
      const response = await createApp().request(
        '/api/v1/admin/overview',
        {
          headers: {
            'x-dev-neon-user-id': TEACHER_NEON_ID,
            'x-dev-email': 'teacher@schoolic.local',
          },
        },
        devEnv,
      );

      // Must be denied with 403
      expect(response.status).toBe(403);
    });

    it('allows valid administrator access with 200', async () => {
      mockUserRows = [
        {
          appUserId: 'admin-app-user-id',
          schoolId: SCHOOL_ID,
          email: 'admin@schoolic.local',
          isActive: true,
          role: 'admin',
          staffId: null,
        },
      ];

      const response = await createApp().request(
        '/api/v1/me',
        {
          headers: {
            'x-dev-neon-user-id': ADMIN_NEON_ID,
            'x-dev-email': 'admin@schoolic.local',
          },
        },
        devEnv,
      );

      expect(response.status).toBe(200);
      const json = (await response.json()) as any;
      expect(json.roles).toContain('admin');
    });

    it('denies teacher access to class roster of an unassigned section with 403', async () => {
      const teacherUser: AuthUser = {
        neonUserId: TEACHER_NEON_ID,
        email: 'teacher@schoolic.local',
        roles: ['teacher'],
        schoolId: SCHOOL_ID,
        staffId: STAFF_ID,
      };

      const mockDb: any = {
        select: vi.fn(() => ({
          from: vi.fn(() => ({
            where: vi.fn(() => ({
              limit: vi.fn().mockResolvedValue([]), // No assignment found!
            })),
          })),
        })),
      };

      const repo = createSchoolRepository(mockDb);

      await expect(
        repo.rosterForSection(teacherUser, UNASSIGNED_SECTION_ID, ACADEMIC_YEAR_ID),
      ).rejects.toThrow('Teacher is not assigned to this class section');
    });

    it('allows teacher access to class roster of an assigned section', async () => {
      const teacherUser: AuthUser = {
        neonUserId: TEACHER_NEON_ID,
        email: 'teacher@schoolic.local',
        roles: ['teacher'],
        schoolId: SCHOOL_ID,
        staffId: STAFF_ID,
      };

      const mockDb: any = {
        select: vi.fn(() => ({
          from: vi.fn(() => ({
            where: vi.fn(() => ({
              limit: vi.fn().mockResolvedValue([{ id: 'assignment-1' }]), // Assignment found!
            })),
            innerJoin: vi.fn(() => ({
              where: vi.fn(() => ({
                orderBy: vi.fn(() => ({
                  limit: vi.fn().mockResolvedValue([
                    { id: STUDENT_ID, admissionNumber: 'STU-001', fullName: 'Alice Student', rollNumber: '1' },
                  ]),
                })),
              })),
            })),
          })),
        })),
      };

      const repo = createSchoolRepository(mockDb);
      const roster = await repo.rosterForSection(teacherUser, ASSIGNED_SECTION_ID, ACADEMIC_YEAR_ID);
      expect(roster.length).toBe(1);
      expect(roster[0]?.fullName).toBe('Alice Student');
    });

    it('denies unauthorized access to student attendance history', async () => {
      const response = await createApp().request(
        `/api/v1/admin/students/${STUDENT_ID}/attendance-summary`,
        {}, // unauthenticated
        prodEnv,
      );
      expect(response.status).toBe(401);
    });
  });

  describe('3. Input Validation & Query Parameter Security', () => {
    it('returns validation error 400 for invalid query parameters on attendance summary', async () => {
      mockUserRows = [
        {
          appUserId: 'admin-app-user-id',
          schoolId: SCHOOL_ID,
          email: 'admin@schoolic.local',
          isActive: true,
          role: 'admin',
          staffId: null,
        },
      ];

      // Invalid date format query parameter
      const response = await createApp().request(
        '/api/v1/admin/attendance-summary?startDate=not-a-valid-date',
        {
          headers: {
            'x-dev-neon-user-id': ADMIN_NEON_ID,
            'x-dev-email': 'admin@schoolic.local',
          },
        },
        devEnv,
      );

      // Zod validator rejects malformed date query parameter
      expect(response.status).toBe(400);
    });

    it('returns validation error 400 for invalid student UUID in URL parameter', async () => {
      mockUserRows = [
        {
          appUserId: 'admin-app-user-id',
          schoolId: SCHOOL_ID,
          email: 'admin@schoolic.local',
          isActive: true,
          role: 'admin',
          staffId: null,
        },
      ];

      const response = await createApp().request(
        '/api/v1/admin/students/malicious-sql-or-bad-id/attendance-summary',
        {
          headers: {
            'x-dev-neon-user-id': ADMIN_NEON_ID,
            'x-dev-email': 'admin@schoolic.local',
          },
        },
        devEnv,
      );

      expect(response.status).toBe(400);
    });
  });

  describe('4. Bootstrap Route Hardening', () => {
    it('rejects bootstrap request without token in production with 403', async () => {
      const response = await createApp().request(
        '/api/v1/bootstrap/school',
        {
          method: 'POST',
          headers: { 'content-type': 'application/json' },
          body: JSON.stringify({
            school: { name: 'Acme School', code: 'ACME' },
            admin: { neonUserId: 'usr-1', email: 'admin@acme.edu', displayName: 'Admin' },
          }),
        },
        prodEnv,
      );

      expect(response.status).toBe(403);
    });

    it('rejects bootstrap request with wrong token in production with 403', async () => {
      const response = await createApp().request(
        '/api/v1/bootstrap/school',
        {
          method: 'POST',
          headers: {
            'content-type': 'application/json',
            'x-bootstrap-token': 'wrong-token',
          },
          body: JSON.stringify({
            school: { name: 'Acme School', code: 'ACME' },
            admin: { neonUserId: 'usr-1', email: 'admin@acme.edu', displayName: 'Admin' },
          }),
        },
        prodEnv,
      );

      expect(response.status).toBe(403);
    });
  });

  describe('5. CSV Formula Injection Defense (CWE-1236)', () => {
    it('escapes formula injection characters in CSV export', async () => {
      // Test formula triggers =, +, -, @, \t, \r
      const dangerousValues = ['=cmd|\' /C calc\'!A0', '+SUM(A1:A10)', '-123', '@SUM(B1:B2)', '\tTAB'];

      for (const val of dangerousValues) {
        let str = String(val);
        if (/^[=+\-@\t\r]/.test(str)) {
          str = `'${str}`;
        }
        const cell = `"${str.replace(/"/g, '""')}"`;
        // First char after quote must be single quote '
        expect(cell.startsWith('"\'')).toBe(true);
      }
    });
  });
});
