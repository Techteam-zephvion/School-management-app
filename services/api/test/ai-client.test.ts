import { afterEach, describe, expect, it, vi } from 'vitest';
import { z } from 'zod';
import { generateJson, generateJsonWithUsage } from '../src/ai/client';
import { ApiError } from '../src/http/errors';
import type { Env } from '../src/types';

const schema = z.object({ ok: z.boolean() });

const enabledEnv: Env = {
  APP_ENV: 'test',
  CORS_ORIGIN: '*',
  DATABASE_URL: 'postgres://example',
  NEON_AUTH_URL: 'https://auth.example.test',
  AI_FEATURES_ENABLED: 'true',
  AI_MODEL: 'test-model',
  AI_API_KEY: 'test-key',
  AI_BASE_URL: 'https://ai.example.test/v1',
};

describe('AI provider adapter', () => {
  afterEach(() => {
    vi.restoreAllMocks();
  });

  it('fails closed when AI features are disabled', async () => {
    await expect(
      generateJson({ ...enabledEnv, AI_FEATURES_ENABLED: 'false' }, { messages: [], schema }),
    ).rejects.toMatchObject({ status: 503, message: 'AI features are not enabled for this environment.' });
  });

  it('fails closed when provider credentials are missing', async () => {
    const { AI_API_KEY: _apiKey, ...missingKeyEnv } = enabledEnv;

    await expect(generateJson(missingKeyEnv, { messages: [], schema })).rejects.toMatchObject({
      status: 503,
      message: 'AI is not configured for this environment.',
    });
  });

  it('validates structured provider output', async () => {
    vi.spyOn(globalThis, 'fetch').mockResolvedValueOnce(
      new Response(
        JSON.stringify({
          choices: [{ message: { content: JSON.stringify({ ok: true }) } }],
        }),
        { status: 200 },
      ),
    );

    await expect(generateJson(enabledEnv, { messages: [{ role: 'user', content: 'test' }], schema })).resolves.toEqual({
      ok: true,
    });
  });

  it('returns provider token usage when available', async () => {
    vi.spyOn(globalThis, 'fetch').mockResolvedValueOnce(
      new Response(
        JSON.stringify({
          choices: [{ message: { content: JSON.stringify({ ok: true }) } }],
          usage: { prompt_tokens: 7, completion_tokens: 3, total_tokens: 10 },
        }),
        { status: 200 },
      ),
    );

    const result = await generateJsonWithUsage(enabledEnv, { messages: [{ role: 'user', content: 'test' }], schema });

    expect(result.data).toEqual({ ok: true });
    expect(result.usage.inputTokens).toBe(7);
    expect(result.usage.outputTokens).toBe(3);
    expect(result.usage.totalTokens).toBe(10);
    expect(result.usage.latencyMs).toBeGreaterThanOrEqual(0);
  });

  it('rejects malformed provider output without returning raw diagnostics', async () => {
    vi.spyOn(globalThis, 'fetch').mockResolvedValueOnce(
      new Response(
        JSON.stringify({
          choices: [{ message: { content: JSON.stringify({ nope: true }) } }],
        }),
        { status: 200 },
      ),
    );

    await expect(generateJson(enabledEnv, { messages: [{ role: 'user', content: 'test' }], schema })).rejects.toBeInstanceOf(
      ApiError,
    );
  });
});
