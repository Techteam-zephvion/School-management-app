import { describe, expect, it } from 'vitest';
import { createPaymentOrderSchema, verifyPaymentOrderSchema } from '../src/http/validation';
import { CashfreeClient } from '../src/payments/cashfree';

const uuid = '00000000-0000-4000-8000-000000000001';

describe('Payment Validation & Gateway Tests', () => {
  it('validates correct payment order creation payload', () => {
    const valid = {
      allocationId: uuid,
      amount: 15000,
      returnUrl: 'https://schoolic.pages.dev/#/fees?status=success',
    };
    const parsed = createPaymentOrderSchema.parse(valid);
    expect(parsed.amount).toBe(15000);
    expect(parsed.allocationId).toBe(uuid);
  });

  it('rejects invalid or non-positive payment order amounts', () => {
    expect(() =>
      createPaymentOrderSchema.parse({
        allocationId: uuid,
        amount: 0,
      }),
    ).toThrow();

    expect(() =>
      createPaymentOrderSchema.parse({
        allocationId: uuid,
        amount: -500,
      }),
    ).toThrow();
  });

  it('validates verify payment order input', () => {
    const parsed = verifyPaymentOrderSchema.parse({
      orderId: 'SCH_1728900000_ABCDE',
    });
    expect(parsed.orderId).toBe('SCH_1728900000_ABCDE');
  });

  it('runs Cashfree simulator when credentials are not configured', async () => {
    const client = new CashfreeClient({
      APP_ENV: 'test',
      DATABASE_URL: 'postgres://localhost/test',
    });

    const res = await client.createOrder({
      orderId: 'SCH_TEST_123',
      orderAmount: 5000,
      customerId: 'student_123',
      customerName: 'Aarav Sharma',
      customerEmail: 'parent@schoolic.edu',
      customerPhone: '9876543210',
    });

    expect(res.isSimulated).toBe(true);
    expect(res.paymentSessionId).toContain('sim_session_SCH_TEST_123');
    expect(res.orderStatus).toBe('ACTIVE');

    const payments = await client.getPayments('SCH_TEST_123');
    expect(payments.length).toBeGreaterThan(0);
    expect(payments[0]?.paymentStatus).toBe('SUCCESS');
  });

  it('computes and verifies HMAC-SHA256 webhook signatures accurately', async () => {
    const secret = 'test_secret_key_12345';
    const timestamp = '1728900000';
    const rawBody = JSON.stringify({ type: 'PAYMENT_SUCCESS_WEBHOOK', order: { order_id: 'SCH_123' } });

    // Compute signature using crypto
    const data = `${timestamp}${rawBody}`;
    const encoder = new TextEncoder();
    const cryptoKey = await crypto.subtle.importKey(
      'raw',
      encoder.encode(secret),
      { name: 'HMAC', hash: 'SHA-256' },
      false,
      ['sign'],
    );
    const signatureBytes = await crypto.subtle.sign('HMAC', cryptoKey, encoder.encode(data));
    const validSignature = btoa(String.fromCharCode(...new Uint8Array(signatureBytes)));

    const verified = await CashfreeClient.verifyWebhookSignature({
      rawBody,
      signature: validSignature,
      timestamp,
      secretKey: secret,
    });
    expect(verified).toBe(true);

    const tampered = await CashfreeClient.verifyWebhookSignature({
      rawBody: rawBody + 'tamper',
      signature: validSignature,
      timestamp,
      secretKey: secret,
    });
    expect(tampered).toBe(false);
  });

  it.runIf(Boolean(process.env.CASHFREE_SECRET_KEY))(
    'interacts directly with live Cashfree Sandbox using provided sandbox credentials',
    async () => {
      const appId = process.env.CASHFREE_APP_ID || 'TEST112097243d3d637f11e796a7739842790211';
      const secretKey = process.env.CASHFREE_SECRET_KEY!;

      const client = new CashfreeClient({
        APP_ENV: 'production',
        DATABASE_URL: 'postgres://localhost/test',
        CASHFREE_APP_ID: appId,
        CASHFREE_SECRET_KEY: secretKey,
        CASHFREE_ENV: 'sandbox',
        CASHFREE_API_VERSION: '2023-08-01',
      });

    const testOrderId = `VITEST_${Date.now()}`;
    const orderRes = await client.createOrder({
      orderId: testOrderId,
      orderAmount: 150,
      customerId: 'student_vitest_1',
      customerName: 'Test Student',
      customerEmail: 'student@schoolic.edu',
      customerPhone: '9876543210',
    });

    expect(orderRes.isSimulated).toBe(false);
    expect(orderRes.cfOrderId).toBeDefined();
    expect(orderRes.paymentSessionId).toBeDefined();
    expect(orderRes.paymentSessionId).toContain('session_');

    // Trigger test settlement via Cashfree sandbox session payment
    const payOk = await client.payOrderSession(orderRes.paymentSessionId);
    expect(payOk).toBe(true);

    // Fetch payments from Cashfree Sandbox
    const payments = await client.getPayments(testOrderId);
    expect(payments.length).toBeGreaterThan(0);
    expect(payments[0]?.paymentStatus).toBe('SUCCESS');
    expect(payments[0]?.cfPaymentId).toBeDefined();
  });
});
