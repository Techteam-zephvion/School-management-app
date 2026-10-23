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
  createStudentLeaveSchema,
  bookPtmSlotSchema,
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

// ==========================================
// Phase 12: Parent / Student Portal Operations
// ==========================================

// 1. Leaves
portalRoutes.get('/leaves', zValidator('query', portalStudentQuerySchema), async (c) => {
  const authUser = c.get('authUser');
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  const studentId = c.req.valid('query').studentId;
  return c.json(await repo.listStudentLeaves(authUser, { studentId }));
});

portalRoutes.post('/leaves', zValidator('json', createStudentLeaveSchema), async (c) => {
  const authUser = c.get('authUser');
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  return c.json(await repo.createStudentLeave(authUser, c.req.valid('json')), 201);
});

// 2. Transport
portalRoutes.get('/transport', zValidator('query', portalStudentQuerySchema), async (c) => {
  const authUser = c.get('authUser');
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  let studentId = c.req.valid('query').studentId;
  if (!studentId) {
    const profile = await repo.portalProfile(authUser);
    studentId = profile.students[0]?.id;
  }
  if (!studentId) {
    return c.json({ isAllocated: false });
  }
  return c.json(await repo.getStudentTransportOverview(authUser, studentId));
});

portalRoutes.get('/transport/track', zValidator('query', portalStudentQuerySchema), async (c) => {
  const authUser = c.get('authUser');
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  let studentId = c.req.valid('query').studentId;
  if (!studentId) {
    const profile = await repo.portalProfile(authUser);
    studentId = profile.students[0]?.id;
  }
  if (!studentId) {
    return c.json({ isAllocated: false });
  }
  return c.json(await repo.getStudentTransportOverview(authUser, studentId));
});

// 3. Certificates
portalRoutes.get('/certificates', zValidator('query', portalStudentQuerySchema), async (c) => {
  const authUser = c.get('authUser');
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  const studentId = c.req.valid('query').studentId;
  return c.json(await repo.listCertificates(authUser, { studentId }));
});

// 4. Calendar & PTM
portalRoutes.get('/calendar', async (c) => {
  const authUser = c.get('authUser');
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  return c.json(await repo.listCalendarEvents(authUser, { targetAudience: 'students' }));
});

portalRoutes.get('/ptm/slots', async (c) => {
  const authUser = c.get('authUser');
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  return c.json(await repo.listPtmSlots(authUser));
});

portalRoutes.post('/ptm/book', zValidator('json', bookPtmSlotSchema), async (c) => {
  const authUser = c.get('authUser');
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  return c.json(await repo.bookPtmSlot(authUser, c.req.valid('json')));
});

portalRoutes.put(
  '/ptm/cancel/:slotId',
  zValidator('param', z.object({ slotId: z.string().uuid() })),
  async (c) => {
    const authUser = c.get('authUser');
    const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
    return c.json(await repo.cancelPtmBooking(authUser, c.req.valid('param').slotId));
  },
);

// Phase 13: Board-Specific Report Cards for Portal
portalRoutes.get('/board-report-cards', zValidator('query', portalStudentQuerySchema), async (c) => {
  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  return c.json(await repo.portalBoardReportCards(c.get('authUser'), c.req.valid('query').studentId));
});

