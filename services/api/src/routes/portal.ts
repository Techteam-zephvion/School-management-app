import { zValidator } from '@hono/zod-validator';
import { Hono } from 'hono';
import { z } from 'zod';
import { createDb } from '../db/client';
import { requireRole } from '../http/auth';
import { rateLimiter } from '../http/rate-limiter';
import {
  portalStudentQuerySchema,
  submitHomeworkSchema,
  createPaymentOrderSchema,
  verifyPaymentOrderSchema,
  createChatConversationSchema,
  sendChatMessageSchema,
  createDsrRequestSchema,
} from '../http/validation';
import { createSchoolRepository } from '../repositories/school-repository';
import type { AppBindings } from '../types';

export const portalRoutes = new Hono<AppBindings>();

portalRoutes.use('*', async (c, next) => {
  requireRole(c.get('authUser'), ['student', 'parent', 'admin']);
  await next();
});

portalRoutes.get('/profile', async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  return c.json(await repo.portalProfile(c.get('authUser')));
});

portalRoutes.get('/announcements', zValidator('query', portalStudentQuerySchema), async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  return c.json(await repo.portalAnnouncements(c.get('authUser'), c.req.valid('query').studentId));
});

portalRoutes.get('/attendance', zValidator('query', portalStudentQuerySchema), async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  return c.json(await repo.portalAttendance(c.get('authUser'), c.req.valid('query').studentId));
});

portalRoutes.get('/timetable', zValidator('query', portalStudentQuerySchema), async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  return c.json(await repo.portalTimetable(c.get('authUser'), c.req.valid('query').studentId));
});

portalRoutes.get('/homework', zValidator('query', portalStudentQuerySchema), async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  return c.json(await repo.portalHomework(c.get('authUser'), c.req.valid('query').studentId));
});

portalRoutes.post('/homework/:assignmentId/submit', zValidator('json', submitHomeworkSchema), async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  const assignmentId = c.req.param('assignmentId');
  return c.json(await repo.portalSubmitHomework(c.get('authUser'), assignmentId, c.req.valid('json')), 201);
});

portalRoutes.get('/report-card', zValidator('query', portalStudentQuerySchema), async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  return c.json(await repo.portalReportCard(c.get('authUser'), c.req.valid('query').studentId));
});

portalRoutes.get('/fees', zValidator('query', portalStudentQuerySchema), async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  return c.json(await repo.portalFeeSummary(c.get('authUser'), c.req.valid('query').studentId));
});

portalRoutes.post(
  '/fees/orders',
  rateLimiter({ maxRequests: 20, windowSeconds: 60, keyPrefix: 'rl:portal-order' }),
  zValidator('json', createPaymentOrderSchema),
  async (c) => {
    const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
    const res = await repo.createPaymentOrder(c.get('authUser'), c.req.valid('json'), c.env);
    return c.json(res, 201);
  },
);

portalRoutes.post(
  '/fees/verify',
  rateLimiter({ maxRequests: 30, windowSeconds: 60, keyPrefix: 'rl:portal-verify' }),
  zValidator('json', verifyPaymentOrderSchema),
  async (c) => {
    const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
    const res = await repo.verifyPaymentOrder(c.get('authUser'), c.req.valid('json').orderId, c.env);
    return c.json(res);
  },
);

portalRoutes.get('/id-card', zValidator('query', portalStudentQuerySchema), async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  return c.json(await repo.portalIdCard(c.get('authUser'), c.req.valid('query').studentId));
});

portalRoutes.get('/notifications', async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  return c.json(await repo.portalNotifications(c.get('authUser')));
});

portalRoutes.get('/chat/conversations', async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  return c.json(await repo.listChatConversations(c.get('authUser')));
});

portalRoutes.post('/chat/conversations', zValidator('json', createChatConversationSchema), async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  return c.json(await repo.createChatConversation(c.get('authUser'), c.req.valid('json')), 201);
});

portalRoutes.get(
  '/chat/conversations/:id/messages',
  zValidator('param', z.object({ id: z.string().uuid() })),
  async (c) => {
    const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
    return c.json(await repo.listChatMessages(c.get('authUser'), c.req.valid('param').id));
  },
);

portalRoutes.post(
  '/chat/conversations/:id/messages',
  zValidator('param', z.object({ id: z.string().uuid() })),
  zValidator('json', sendChatMessageSchema),
  async (c) => {
    const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
    return c.json(
      await repo.sendChatMessage(c.get('authUser'), c.req.valid('param').id, c.req.valid('json')),
      201,
    );
  },
);

// Phase 11: Data Subject Rights (DSR) in Parent/Student Portal
portalRoutes.post('/dpdp/dsr', zValidator('json', createDsrRequestSchema), async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  return c.json(await repo.createDsrRequest(c.get('authUser'), c.req.valid('json')), 201);
});

portalRoutes.get('/dpdp/dsr', async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  return c.json(await repo.listDsrRequests(c.get('authUser')));
});

portalRoutes.get('/dpdp/consents', async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  return c.json(await repo.listDpdpConsents(c.get('authUser')));
});

