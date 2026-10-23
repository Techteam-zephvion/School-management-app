import { describe, expect, it } from 'vitest';
import { createApp } from '../src/index';

describe('Google Play Legal & Privacy Compliance Routes', () => {
  const app = createApp();

  it('serves Privacy Policy at /privacy with HTML content and package ID', async () => {
    const res = await app.request('/privacy');
    expect(res.status).toBe(200);
    const text = await res.text();
    expect(text).toContain('com.zephvion.schoolic');
    expect(text).toContain('Privacy Policy &amp; Data Safety');
    expect(text).toContain('Ads Declaration');
    expect(text).toContain('Health Apps Declaration');
    expect(text).toContain('Account Deletion &amp; Data Erasure');
    expect(text).toContain('privacy@zephvion.com');
  });

  it('serves Terms of Service at /terms with HTML content', async () => {
    const res = await app.request('/terms');
    expect(res.status).toBe(200);
    const text = await res.text();
    expect(text).toContain('Terms of Service');
    expect(text).toContain('com.zephvion.schoolic');
  });

  it('serves account deletion instructions at /data-deletion', async () => {
    const res = await app.request('/data-deletion');
    expect(res.status).toBe(200);
    const text = await res.text();
    expect(text).toContain('Account &amp; Data Deletion');
  });

  it('serves public API aliases under /api/v1/public/privacy and terms', async () => {
    const privRes = await app.request('/api/v1/public/privacy');
    expect(privRes.status).toBe(200);
    const termsRes = await app.request('/api/v1/public/terms');
    expect(termsRes.status).toBe(200);
  });
});
