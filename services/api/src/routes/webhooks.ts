import { Hono } from 'hono';
import { createDb } from '../db/client';
import { CashfreeClient } from '../payments/cashfree';
import { createSchoolRepository } from '../repositories/school-repository';
import type { AppBindings } from '../types';

export const webhookRoutes = new Hono<AppBindings>();

webhookRoutes.post('/cashfree', async (c) => {
  const signature = c.req.header('x-webhook-signature');
  const timestamp = c.req.header('x-webhook-timestamp');
  const rawBody = await c.req.text();

  if (c.env.CASHFREE_SECRET_KEY) {
    if (!signature || !timestamp) {
      return c.json({ error: 'Missing webhook signature headers' }, 400);
    }
    const isValid = await CashfreeClient.verifyWebhookSignature({
      signature,
      rawBody,
      timestamp,
      secretKey: c.env.CASHFREE_SECRET_KEY,
      maxSkewMs: 5 * 60 * 1000,
    });
    if (!isValid) {
      return c.json({ error: 'Invalid webhook signature or expired timestamp' }, 401);
    }
  }

  let payload: Record<string, unknown>;
  try {
    payload = JSON.parse(rawBody);
  } catch {
    return c.json({ error: 'Invalid JSON payload' }, 400);
  }

  const repo = createSchoolRepository(createDb(c.env.DATABASE_URL));
  const res = await repo.handleCashfreeWebhook(payload, c.env);
  return c.json(res);
});
