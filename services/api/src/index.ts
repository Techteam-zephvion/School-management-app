import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { logger } from 'hono/logger';
import { authenticate } from './http/auth';
import { fail } from './http/errors';
import { adminRoutes } from './routes/admin';
import { bootstrapRoutes } from './routes/bootstrap';
import { portalRoutes } from './routes/portal';
import { teacherRoutes } from './routes/teacher';
import type { AppBindings } from './types';

export function createApp() {
  const app = new Hono<AppBindings>();

  app.use('*', logger());
  app.use('*', async (c, next) => {
    const isProduction = c.env.APP_ENV === 'production';
    const configuredOrigins = (c.env.CORS_ORIGIN || '')
      .split(',')
      .map((o) => o.trim())
      .filter(Boolean);

    const defaultDevOrigins = ['http://localhost:8080', 'http://127.0.0.1:8080', 'http://localhost:3000'];
    const allowedOrigins = configuredOrigins.length > 0 ? configuredOrigins : isProduction ? [] : defaultDevOrigins;

    const middleware = cors({
      origin: (requestOrigin) => {
        if (!requestOrigin) {
          return allowedOrigins[0] ?? '';
        }
        if (allowedOrigins.includes(requestOrigin)) {
          return requestOrigin;
        }
        if (!isProduction && (requestOrigin.startsWith('http://localhost:') || requestOrigin.startsWith('http://127.0.0.1:'))) {
          return requestOrigin;
        }
        return '';
      },
      allowHeaders: ['content-type', 'authorization', 'x-dev-neon-user-id', 'x-dev-email', 'x-bootstrap-token'],
      allowMethods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
      credentials: true,
    });
    return middleware(c, next);
  });

  app.onError((error, c) => fail(c, error));
  app.get('/health', (c) => c.json({ ok: true, service: 'schoolic-api' }));

  app.route('/api/v1/bootstrap', bootstrapRoutes);

  app.use('/api/v1/*', authenticate);
  app.get('/api/v1/me', (c) => c.json(c.get('authUser')));
  app.route('/api/v1/admin', adminRoutes);
  app.route('/api/v1/teacher', teacherRoutes);
  app.route('/api/v1/portal', portalRoutes);

  return app;
}

export default createApp();
