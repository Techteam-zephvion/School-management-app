import { z } from 'zod';
import { ApiError } from '../http/errors';
import type { Env } from '../types';

type Message = {
  role: 'system' | 'user';
  content: string;
};

type GenerateOptions<T extends z.ZodType> = {
  messages: Message[];
  schema: T;
  maxTokens?: number;
  timeoutMs?: number;
};

export type AiUsageMetadata = {
  inputTokens: number | null;
  outputTokens: number | null;
  totalTokens: number | null;
  latencyMs: number;
  model: string;
};

export async function generateJson<T extends z.ZodType>(
  env: Env,
  options: GenerateOptions<T>,
): Promise<z.infer<T>> {
  const result = await generateJsonWithUsage(env, options);
  return result.data;
}

export async function generateJsonWithUsage<T extends z.ZodType>(
  env: Env,
  options: GenerateOptions<T>,
): Promise<{ data: z.infer<T>; usage: AiUsageMetadata }> {
  const apiKey = env.AI_API_KEY;
  const model = env.AI_MODEL;
  const baseUrl = (env.AI_BASE_URL || 'https://api.openai.com/v1').replace(/\/$/, '');

  if (env.AI_FEATURES_ENABLED !== 'true') {
    throw new ApiError(503, 'AI features are not enabled for this environment.');
  }
  if (!apiKey || !model) {
    throw new ApiError(503, 'AI is not configured for this environment.');
  }

  const controller = new AbortController();
  const timeoutMs = options.timeoutMs ?? numberFromEnv(env.AI_TIMEOUT_MS, 18000);
  const maxTokens = Math.min(options.maxTokens ?? 900, numberFromEnv(env.AI_MAX_OUTPUT_TOKENS, 1200));
  const startedAt = Date.now();
  const timer = setTimeout(() => controller.abort(), timeoutMs);

  try {
    const response = await fetch(`${baseUrl}/chat/completions`, {
      method: 'POST',
      headers: {
        authorization: `Bearer ${apiKey}`,
        'content-type': 'application/json',
      },
      body: JSON.stringify({
        model,
        messages: options.messages,
        temperature: 0.2,
        max_tokens: maxTokens,
        response_format: { type: 'json_object' },
      }),
      signal: controller.signal,
    });

    if (response.status === 429) {
      throw new ApiError(429, 'AI provider is rate limiting requests. Please try again shortly.');
    }
    if (!response.ok) {
      throw new ApiError(503, 'AI provider request failed. Please try again later.');
    }

    const payload = (await response.json()) as {
      choices?: Array<{ message?: { content?: string } }>;
      usage?: {
        prompt_tokens?: number;
        completion_tokens?: number;
        total_tokens?: number;
      };
    };
    const content = payload.choices?.[0]?.message?.content;
    if (!content || content.length > 12000) {
      throw new ApiError(503, 'AI provider returned an invalid response.');
    }

    const parsed = parseJsonContent(content);
    const validated = options.schema.safeParse(parsed);
    if (!validated.success) {
      throw new ApiError(503, 'AI provider response did not match the expected format.');
    }
    return {
      data: validated.data,
      usage: {
        inputTokens: payload.usage?.prompt_tokens ?? null,
        outputTokens: payload.usage?.completion_tokens ?? null,
        totalTokens: payload.usage?.total_tokens ?? null,
        latencyMs: Date.now() - startedAt,
        model,
      },
    };
  } catch (error) {
    if (error instanceof ApiError) throw error;
    if (error instanceof DOMException && error.name === 'AbortError') {
      throw new ApiError(504, 'AI provider request timed out.');
    }
    throw new ApiError(503, 'AI provider is unavailable.');
  } finally {
    clearTimeout(timer);
  }
}

function numberFromEnv(value: string | undefined, fallback: number) {
  const parsed = Number(value);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}

function parseJsonContent(content: string): unknown {
  const trimmed = content.trim();
  const fenced = trimmed.match(/^```(?:json)?\s*([\s\S]*?)\s*```$/);
  const body = fenced?.[1] ?? trimmed;
  return JSON.parse(body);
}
