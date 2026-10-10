import { and, eq } from 'drizzle-orm';
import { createMiddleware } from 'hono/factory';
import { ApiError } from './errors';
import { createDb } from '../db/client';
import { appUsers, staff, userRoles } from '../db/schema';
import type { AppBindings, AuthUser, Role } from '../types';

type NeonSessionResponse = {
  user?: {
    id?: string;
    email?: string;
  };
};

async function readNeonSession(
  authUrl: string,
  credential: { bearer?: string; cookie?: string },
): Promise<{ id: string; email: string }> {
  try {
    const url = `${authUrl.replace(/\/$/, '')}/auth/session`;
    const response = await fetch(url, {
      headers: {
        ...(credential.bearer ? { authorization: `Bearer ${credential.bearer}` } : {}),
        ...(credential.cookie ? { cookie: credential.cookie } : {}),
        accept: 'application/json',
      },
    });

    if (response.status === 401 || response.status === 403) {
      throw new ApiError(401, 'Invalid or expired session');
    }

    if (!response.ok) {
      throw new ApiError(401, 'Authentication verification failed');
    }

    const body = (await response.json()) as NeonSessionResponse;
    if (!body.user?.id || !body.user.email) {
      throw new ApiError(401, 'Auth session did not include a valid user');
    }

    return { id: body.user.id, email: body.user.email };
  } catch (error) {
    if (error instanceof ApiError) throw error;
    console.error('Error verifying session with authentication service:', error);
    throw new ApiError(401, 'Unable to verify authentication credentials');
  }
}

export const authenticate = createMiddleware<AppBindings>(async (c, next) => {
  const devUserId = c.req.header('x-dev-neon-user-id');
  const devEmail = c.req.header('x-dev-email');
  const bearer = c.req.header('authorization')?.replace(/^Bearer\s+/i, '');
  const cookie = c.req.header('cookie');

  const isProduction = c.env.APP_ENV === 'production';
  const isDevelopmentOrTest = c.env.APP_ENV === 'development' || c.env.APP_ENV === 'test';

  let sessionUser: { id: string; email: string };

  if (bearer || cookie) {
    if (!c.env.NEON_AUTH_URL) {
      console.error('NEON_AUTH_URL configuration missing on server');
      throw new ApiError(500, 'Authentication service misconfigured');
    }
    sessionUser = await readNeonSession(c.env.NEON_AUTH_URL, {
      ...(bearer ? { bearer } : {}),
      ...(cookie ? { cookie } : {}),
    });
  } else if (!isProduction && isDevelopmentOrTest && devUserId && devEmail) {
    // Development authentication bypass: STRICTLY allowed only in local development/test environments
    sessionUser = { id: devUserId, email: devEmail };
  } else {
    // In production, or whenever credentials are not supplied, fail closed with 401
    throw new ApiError(401, 'Authentication required');
  }

  const db = createDb(c.env.DATABASE_URL);
  const rows = await db
    .select({
      appUserId: appUsers.id,
      schoolId: appUsers.schoolId,
      email: appUsers.email,
      isActive: appUsers.isActive,
      role: userRoles.role,
      staffId: staff.id,
    })
    .from(appUsers)
    .leftJoin(userRoles, eq(userRoles.userId, appUsers.id))
    .leftJoin(staff, eq(staff.userId, appUsers.id))
    .where(and(eq(appUsers.neonUserId, sessionUser.id), eq(appUsers.isActive, true)));

  if (rows.length === 0) {
    throw new ApiError(403, 'User is not provisioned for this pilot');
  }

  const first = rows[0]!;
  const roles = rows.map((row) => row.role).filter((role): role is Role => Boolean(role));
  const authUser: AuthUser = {
    neonUserId: sessionUser.id,
    email: first.email || sessionUser.email,
    schoolId: first.schoolId,
    roles,
    staffId: first.staffId,
  };

  c.set('authUser', authUser);
  await next();
});

export function requireRole(user: AuthUser, allowed: Role[]) {
  if (!user.roles.some((role) => allowed.includes(role))) {
    throw new ApiError(403, 'Insufficient permissions');
  }
}
