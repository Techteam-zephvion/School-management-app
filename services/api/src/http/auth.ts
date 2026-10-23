import { and, eq } from 'drizzle-orm';
import { createMiddleware } from 'hono/factory';
import { ApiError } from './errors';
import { createDb } from '../db/client';
import { appUsers, staff, userRoles } from '../db/schema';
import type { AppBindings, AuthUser, Role } from '../types';

type NeonSessionResponse = {
  session?: {
    token?: string;
  };
  user?: {
    id?: string;
    email?: string;
  };
};

type NeonJwtPayload = {
  sub?: string;
  id?: string;
  email?: string;
  exp?: number;
  iss?: string;
};

type JwkSet = {
  keys?: Array<JsonWebKey & { kid?: string }>;
};

function decodeBase64Url(value: string): Uint8Array {
  const normalized = value.replace(/-/g, '+').replace(/_/g, '/');
  const padded = normalized.padEnd(Math.ceil(normalized.length / 4) * 4, '=');
  const binary = atob(padded);
  return Uint8Array.from(binary, (char) => char.charCodeAt(0));
}

function decodeJwtPart<T>(value: string): T {
  const bytes = decodeBase64Url(value);
  const text = new TextDecoder().decode(bytes);
  return JSON.parse(text) as T;
}

function isJwt(value: string): boolean {
  return value.split('.').length === 3;
}

function neonAuthBase(authUrl: string): string {
  const trimmed = authUrl.replace(/\/$/, '');
  return trimmed.endsWith('/auth') ? trimmed : `${trimmed}/auth`;
}

let cachedJwks: { keys: JwkSet; fetchedAt: number; authBase: string } | null = null;
const JWKS_CACHE_TTL_MS = 60 * 60 * 1000; // 1 hour

async function getJwks(authBase: string): Promise<JwkSet> {
  const now = Date.now();
  if (cachedJwks && cachedJwks.authBase === authBase && now - cachedJwks.fetchedAt < JWKS_CACHE_TTL_MS) {
    return cachedJwks.keys;
  }

  const jwksResponse = await fetch(`${authBase}/.well-known/jwks.json`, {
    headers: { accept: 'application/json' },
  });

  if (!jwksResponse.ok) {
    if (cachedJwks && cachedJwks.authBase === authBase) {
      return cachedJwks.keys;
    }
    throw new ApiError(503, 'Authentication provider key service unavailable');
  }

  const keys = (await jwksResponse.json()) as JwkSet;
  cachedJwks = { keys, fetchedAt: now, authBase };
  return keys;
}

async function readNeonJwt(authUrl: string, token: string): Promise<{ id: string; email: string }> {
  const [headerPart, payloadPart, signaturePart] = token.split('.');
  if (!headerPart || !payloadPart || !signaturePart) {
    throw new ApiError(401, 'Invalid or expired session');
  }

  const header = decodeJwtPart<{ alg?: string; kid?: string }>(headerPart);
  const payload = decodeJwtPart<NeonJwtPayload>(payloadPart);
  if (header.alg !== 'EdDSA' || !header.kid) {
    throw new ApiError(401, 'Invalid or expired session');
  }

  const now = Math.floor(Date.now() / 1000);
  if (!payload.exp || payload.exp <= now || !payload.email || !(payload.sub || payload.id)) {
    throw new ApiError(401, 'Invalid or expired session');
  }

  const authBase = neonAuthBase(authUrl);
  const expectedIssuer = new URL(authBase).origin;
  if (payload.iss && payload.iss !== expectedIssuer) {
    throw new ApiError(401, 'Invalid or expired session');
  }

  const jwks = await getJwks(authBase);
  let jwk = jwks.keys?.find((key) => key.kid === header.kid);
  if (!jwk && cachedJwks) {
    cachedJwks = null;
    const freshJwks = await getJwks(authBase);
    jwk = freshJwks.keys?.find((key) => key.kid === header.kid);
  }
  if (!jwk) {
    throw new ApiError(401, 'Invalid or expired session');
  }

  const key = await crypto.subtle.importKey(
    'jwk',
    jwk,
    { name: 'Ed25519' },
    false,
    ['verify'],
  );
  const verified = await crypto.subtle.verify(
    { name: 'Ed25519' },
    key,
    decodeBase64Url(signaturePart),
    new TextEncoder().encode(`${headerPart}.${payloadPart}`),
  );
  if (!verified) {
    throw new ApiError(401, 'Invalid or expired session');
  }

  return { id: payload.sub || payload.id!, email: payload.email };
}

async function readNeonSession(
  authUrl: string,
  credential: { bearer?: string; cookie?: string },
): Promise<{ id: string; email: string }> {
  try {
    if (credential.bearer && isJwt(credential.bearer)) {
      return await readNeonJwt(authUrl, credential.bearer);
    }

    const url = `${neonAuthBase(authUrl)}/get-session`;
    const sessionCookie = credential.bearer
      ? `__Secure-neon-auth.session_token=${credential.bearer}`
      : credential.cookie;
    const response = await fetch(url, {
      headers: {
        ...(sessionCookie ? { cookie: sessionCookie } : {}),
        accept: 'application/json',
      },
    });

    if (response.status === 401 || response.status === 403) {
      throw new ApiError(401, 'Invalid or expired session');
    }

    if (!response.ok) {
      throw new ApiError(401, 'Invalid or expired session');
    }

    const body = (await response.json()) as NeonSessionResponse | null;
    if (!body || !body.user?.id || !body.user.email) {
      throw new ApiError(401, 'Invalid or expired session');
    }

    return { id: body.user.id, email: body.user.email };
  } catch (error) {
    if (error instanceof ApiError) throw error;
    console.error('Error verifying session with authentication service:', error);
    throw new ApiError(401, 'Invalid or expired session');
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
  let rows = await db
    .select({
      appUserId: appUsers.id,
      schoolId: appUsers.schoolId,
      email: appUsers.email,
      displayName: appUsers.displayName,
      isActive: appUsers.isActive,
      role: userRoles.role,
      staffId: staff.id,
      staffName: staff.fullName,
    })
    .from(appUsers)
    .leftJoin(userRoles, eq(userRoles.userId, appUsers.id))
    .leftJoin(staff, eq(staff.userId, appUsers.id))
    .where(and(eq(appUsers.neonUserId, sessionUser.id), eq(appUsers.isActive, true)));

  if (rows.length === 0 && sessionUser.email) {
    const userEmailLower = sessionUser.email.toLowerCase().trim();
    const [matchingByEmail] = await db
      .select({ id: appUsers.id })
      .from(appUsers)
      .where(and(eq(appUsers.email, userEmailLower), eq(appUsers.isActive, true)))
      .limit(1);

    if (matchingByEmail) {
      await db
        .update(appUsers)
        .set({ neonUserId: sessionUser.id, updatedAt: new Date() })
        .where(eq(appUsers.id, matchingByEmail.id));

      rows = await db
        .select({
          appUserId: appUsers.id,
          schoolId: appUsers.schoolId,
          email: appUsers.email,
          displayName: appUsers.displayName,
          isActive: appUsers.isActive,
          role: userRoles.role,
          staffId: staff.id,
          staffName: staff.fullName,
        })
        .from(appUsers)
        .leftJoin(userRoles, eq(userRoles.userId, appUsers.id))
        .leftJoin(staff, eq(staff.userId, appUsers.id))
        .where(and(eq(appUsers.neonUserId, sessionUser.id), eq(appUsers.isActive, true)));
    }
  }

  if (rows.length === 0) {
    throw new ApiError(403, 'User is not provisioned for this pilot');
  }

  const first = rows[0]!;
  const roles = rows.map((row) => row.role).filter((role): role is Role => Boolean(role));
  const authUser: AuthUser = {
    appUserId: first.appUserId,
    neonUserId: sessionUser.id,
    email: first.email || sessionUser.email,
    schoolId: first.schoolId,
    roles,
    staffId: first.staffId,
    displayName: first.staffName || first.displayName || null,
  };

  c.set('authUser', authUser);
  await next();
});

export function requireRole(user: AuthUser, allowed: Role[]) {
  if (!user.roles.some((role) => allowed.includes(role))) {
    throw new ApiError(403, 'Insufficient permissions');
  }
}
