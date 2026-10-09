import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { logger } from 'hono/logger';
import { authenticate } from './http/auth';
import { fail } from './http/errors';
import { adminRoutes } from './routes/admin';
import { bootstrapRoutes } from './routes/bootstrap';
import { teacherRoutes } from './routes/teacher';
import type { AppBindings } from './types';

export function createApp() {
  const app = new Hono<AppBindings>();

  app.use('*', logger());
  app.use('*', async (c, next) => {
    const middleware = cors({
      origin: c.env.CORS_ORIGIN || '*',
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

  return app;
}

export default createApp();
