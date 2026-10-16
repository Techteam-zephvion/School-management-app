import { ApiError } from '../http/errors';
import type { Env } from '../types';

export interface CashfreeOrderParams {
  orderId: string;
  orderAmount: number;
  orderCurrency?: string | undefined;
  customerId: string;
  customerName: string;
  customerEmail: string;
  customerPhone: string;
  orderNote?: string | undefined;
  returnUrl?: string | undefined;
  notifyUrl?: string | undefined;
}

export interface CashfreeOrderResult {
  cfOrderId?: string | undefined;
  orderId: string;
  paymentSessionId: string;
  orderStatus: string;
  isSimulated: boolean;
}

export interface CashfreePaymentRecord {
  cfPaymentId: string;
  paymentStatus: 'SUCCESS' | 'FAILED' | 'PENDING' | 'CANCELLED' | 'USER_DROPPED';
  paymentAmount: number;
  paymentCurrency: string;
  paymentMethod: string;
  paymentTime: string;
  bankReference?: string | undefined;
}

export type CashfreeEnv = Partial<Env> & {
  CASHFREE_APP_ID?: string;
  CASHFREE_SECRET_KEY?: string;
  CASHFREE_ENV?: 'sandbox' | 'production';
  CASHFREE_API_VERSION?: string;
};

export class CashfreeClient {
  constructor(private readonly env: CashfreeEnv) {}

  private get isConfigured(): boolean {
    return Boolean(this.env.CASHFREE_APP_ID && this.env.CASHFREE_SECRET_KEY);
  }

  private get baseUrl(): string {
    const isExplicitProd = this.env.CASHFREE_ENV === 'production' && !this.env.CASHFREE_APP_ID?.startsWith('TEST');
    return isExplicitProd
      ? 'https://api.cashfree.com/pg'
      : 'https://sandbox.cashfree.com/pg';
  }

  private get apiVersion(): string {
    return this.env.CASHFREE_API_VERSION || '2023-08-01';
  }

  async createOrder(params: CashfreeOrderParams): Promise<CashfreeOrderResult> {
    if (!this.isConfigured) {
      // Sandbox Simulator fallback when Cashfree credentials are not yet configured in environment
      return {
        cfOrderId: `sim_cf_${params.orderId}`,
        orderId: params.orderId,
        paymentSessionId: `sim_session_${params.orderId}`,
        orderStatus: 'ACTIVE',
        isSimulated: true,
      };
    }

    const payload = {
      order_id: params.orderId,
      order_amount: params.orderAmount,
      order_currency: params.orderCurrency || 'INR',
      customer_details: {
        customer_id: params.customerId.replace(/[^a-zA-Z0-9_-]/g, '_').slice(0, 50),
        customer_name: params.customerName.slice(0, 100),
        customer_email: params.customerEmail,
        customer_phone: params.customerPhone.replace(/[^0-9]/g, '').slice(-10) || '9999999999',
      },
      order_meta: {
        return_url: params.returnUrl,
        notify_url: params.notifyUrl,
      },
      order_note: params.orderNote || 'Schoolic Institutional Fee Payment',
    };

    const response = await fetch(`${this.baseUrl}/orders`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-client-id': this.env.CASHFREE_APP_ID!,
        'x-client-secret': this.env.CASHFREE_SECRET_KEY!,
        'x-api-version': this.apiVersion,
      },
      body: JSON.stringify(payload),
    });

    if (!response.ok) {
      const err = await response.text();
      console.error('Cashfree order creation error:', response.status, err);
      throw new ApiError(500, `Failed to initialize payment gateway order (${response.status})`);
    }

    const data = (await response.json()) as {
      cf_order_id?: string;
      order_id: string;
      payment_session_id: string;
      order_status: string;
    };

    return {
      cfOrderId: data.cf_order_id,
      orderId: data.order_id,
      paymentSessionId: data.payment_session_id,
      orderStatus: data.order_status,
      isSimulated: false,
    };
  }

  async simulatePayment(cfPaymentId: string, status: 'SUCCESS' | 'FAILED' = 'SUCCESS'): Promise<boolean> {
    if (!this.isConfigured) return true;
    try {
      const response = await fetch(`${this.baseUrl}/simulate`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-client-id': this.env.CASHFREE_APP_ID!,
          'x-client-secret': this.env.CASHFREE_SECRET_KEY!,
          'x-api-version': this.apiVersion,
        },
        body: JSON.stringify({
          entity: 'PAYMENTS',
          entity_id: cfPaymentId,
          entity_simulation: {
            payment_status: status,
          },
        }),
      });
      return response.ok;
    } catch (e) {
      console.warn('Failed to simulate payment:', e);
      return false;
    }
  }

  async payOrderSession(paymentSessionId: string, upiId = 'testsuccess@gocash'): Promise<boolean> {
    try {
      const response = await fetch(`${this.baseUrl}/orders/sessions`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-api-version': this.apiVersion,
        },
        body: JSON.stringify({
          payment_session_id: paymentSessionId,
          payment_method: {
            upi: {
              channel: 'collect',
              upi_id: upiId,
            },
          },
        }),
      });

      if (!response.ok) return false;
      const data = (await response.json()) as { cf_payment_id?: string | number };
      const cfPaymentId = data.cf_payment_id ? String(data.cf_payment_id) : undefined;

      // In Sandbox mode, automatically simulate success transition on Cashfree's simulator
      if (cfPaymentId && (this.env.CASHFREE_ENV === 'sandbox' || this.env.CASHFREE_APP_ID?.startsWith('TEST'))) {
        await this.simulatePayment(cfPaymentId, 'SUCCESS');
      }

      return true;
    } catch (e) {
      console.warn('Failed to pay order session in sandbox:', e);
      return false;
    }
  }

  async getPayments(orderId: string): Promise<CashfreePaymentRecord[]> {
    if (!this.isConfigured || orderId.startsWith('sim_')) {
      // Simulator mode fallback if credentials are not set
      return [
        {
          cfPaymentId: `sim_pay_${orderId}`,
          paymentStatus: 'SUCCESS',
          paymentAmount: 0,
          paymentCurrency: 'INR',
          paymentMethod: 'upi',
          paymentTime: new Date().toISOString(),
          bankReference: `SIM-UPI-${Date.now()}`,
        },
      ];
    }

    const response = await fetch(`${this.baseUrl}/orders/${encodeURIComponent(orderId)}/payments`, {
      method: 'GET',
      headers: {
        'x-client-id': this.env.CASHFREE_APP_ID!,
        'x-client-secret': this.env.CASHFREE_SECRET_KEY!,
        'x-api-version': this.apiVersion,
      },
    });

    if (!response.ok) {
      const err = await response.text();
      console.error('Cashfree payment query error:', response.status, err);
      throw new ApiError(500, 'Failed to query payment status from gateway');
    }

    const list = (await response.json()) as Array<{
      cf_payment_id: string | number;
      payment_status: string;
      payment_amount: number;
      payment_currency: string;
      payment_method?: Record<string, unknown> | string;
      payment_time: string;
      bank_reference?: string;
    }>;

    return list.map((item) => {
      let methodStr = 'upi';
      if (typeof item.payment_method === 'string') {
        methodStr = item.payment_method;
      } else if (item.payment_method && typeof item.payment_method === 'object') {
        methodStr = Object.keys(item.payment_method)[0] || 'upi';
      }

      return {
        cfPaymentId: String(item.cf_payment_id),
        paymentStatus: item.payment_status as CashfreePaymentRecord['paymentStatus'],
        paymentAmount: item.payment_amount,
        paymentCurrency: item.payment_currency,
        paymentMethod: methodStr,
        paymentTime: item.payment_time,
        bankReference: item.bank_reference,
      };
    });
  }

  static async verifyWebhookSignature(params: {
    rawBody: string;
    signature: string;
    timestamp: string;
    secretKey: string;
    maxSkewMs?: number;
    currentTimeMs?: number;
  }): Promise<boolean> {
    if (!params.secretKey) return false;

    // Webhook Replay Protection: validate timestamp skew if maxSkewMs is specified
    if (params.maxSkewMs !== undefined && params.maxSkewMs > 0) {
      let tsMs = Number(params.timestamp);
      if (isNaN(tsMs)) {
        tsMs = Date.parse(params.timestamp);
      } else if (tsMs < 10_000_000_000) {
        // Timestamp is in epoch seconds
        tsMs = tsMs * 1000;
      }

      if (isNaN(tsMs)) {
        console.warn('Invalid webhook timestamp header:', params.timestamp);
        return false;
      }

      const now = params.currentTimeMs ?? Date.now();
      const skew = Math.abs(now - tsMs);
      if (skew > params.maxSkewMs) {
        console.warn(`Webhook timestamp skew exceeded (${skew}ms > ${params.maxSkewMs}ms). Potential replay attack rejected.`);
        return false;
      }
    }

    try {
      const data = `${params.timestamp}${params.rawBody}`;
      const encoder = new TextEncoder();
      const keyData = encoder.encode(params.secretKey);
      const cryptoKey = await crypto.subtle.importKey(
        'raw',
        keyData,
        { name: 'HMAC', hash: 'SHA-256' },
        false,
        ['sign'],
      );
      const signatureBytes = await crypto.subtle.sign('HMAC', cryptoKey, encoder.encode(data));
      const computedBase64 = btoa(String.fromCharCode(...new Uint8Array(signatureBytes)));
      return this.timingSafeEqual(computedBase64, params.signature);
    } catch (e) {
      console.error('Error verifying webhook signature:', e);
      return false;
    }
  }

  private static timingSafeEqual(a: string, b: string): boolean {
    if (a.length !== b.length) return false;
    let mismatch = 0;
    for (let i = 0; i < a.length; i++) {
      mismatch |= a.charCodeAt(i) ^ b.charCodeAt(i);
    }
    return mismatch === 0;
  }
}
