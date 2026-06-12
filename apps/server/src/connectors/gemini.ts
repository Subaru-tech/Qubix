import { BaseConnector } from './base';
import {
  AuthenticationError,
  RateLimitError,
  ProviderError,
} from './errors';

interface GeminiConfig {
  apiKey: string;
  model?: string;
  temperature?: number;
  maxTokens?: number;
}

function parseConfig(config: Record<string, unknown>): GeminiConfig {
  const apiKey = config.apiKey as string | undefined;
  if (!apiKey || typeof apiKey !== 'string' || apiKey.trim() === '') {
    throw new AuthenticationError('Connector config invalid: missing required field "apiKey"');
  }
  return {
    apiKey,
    model: (config.model as string) || 'gemini-1.5-flash',
    temperature: typeof config.temperature === 'number' ? config.temperature : 0.7,
    maxTokens: typeof config.maxTokens === 'number' ? config.maxTokens : 2000,
  };
}

function handleErrorStatus(status: number): never {
  if (status === 401 || status === 403) {
    throw new AuthenticationError();
  }
  if (status === 429) {
    throw new RateLimitError(null);
  }
  throw new ProviderError(status, `Gemini service error (HTTP ${status})`);
}

export class GeminiConnector extends BaseConnector {
  private readonly baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models';

  /**
   * Validates the API key by making a lightweight GET request to the models endpoint.
   */
  async validateConfig(config: Record<string, unknown>): Promise<boolean> {
    const parsed = parseConfig(config);

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 10_000);

    try {
      const res = await fetch(`${this.baseUrl}?key=${parsed.apiKey}`, {
        method: 'GET',
        signal: controller.signal,
      });

      if (!res.ok) {
        handleErrorStatus(res.status);
      }

      return true;
    } catch (err) {
      if (err instanceof AuthenticationError || err instanceof RateLimitError || err instanceof ProviderError) {
        throw err;
      }
      throw new ProviderError(0, `Gemini validation failed: ${(err as Error).message}`);
    } finally {
      clearTimeout(timeout);
    }
  }

  /**
   * Sends a chat request to Gemini with streaming enabled.
   */
  async *sendMessage(params: {
    messages: Array<{ role: string; content: string }>;
    threadId: string;
    config: Record<string, unknown>;
  }): AsyncIterable<string> {
    const parsed = parseConfig(params.config);

    // Map messages to Gemini format
    const contents = params.messages.map((msg) => ({
      role: msg.role === 'assistant' ? 'model' : 'user', // Gemini uses 'user' and 'model'
      parts: [{ text: msg.content }],
    }));

    // System instruction
    const systemPrompt = params.config.systemPrompt as string | undefined;
    const systemInstruction = systemPrompt
      ? {
          role: 'user',
          parts: [{ text: systemPrompt }],
        }
      : undefined;

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 60_000);

    try {
      const res = await fetch(`${this.baseUrl}/${parsed.model}:streamGenerateContent?alt=sse&key=${parsed.apiKey}`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          contents,
          ...(systemInstruction ? { systemInstruction } : {}),
          generationConfig: {
            temperature: parsed.temperature,
            maxOutputTokens: parsed.maxTokens,
          },
        }),
        signal: controller.signal,
      });

      if (!res.ok) {
        handleErrorStatus(res.status);
      }

      if (!res.body) {
        throw new ProviderError(0, 'Gemini returned empty response body');
      }

      const reader = res.body.getReader();
      const decoder = new TextDecoder();
      let buffer = '';

      while (true) {
        const { done, value } = await reader.read();
        if (done) break;

        buffer += decoder.decode(value, { stream: true });
        const lines = buffer.split('\n');
        // Keep the last potentially incomplete line in the buffer
        buffer = lines.pop() || '';

        for (const line of lines) {
          const trimmed = line.trim();
          if (!trimmed || trimmed.startsWith(':')) continue;

          if (trimmed.startsWith('data: ')) {
            try {
              const json = JSON.parse(trimmed.slice(6));
              // Gemini SSE format usually has candidates[0].content.parts[0].text
              const parts = json?.candidates?.[0]?.content?.parts;
              if (parts && parts.length > 0) {
                const text = parts[0].text;
                if (text) {
                  yield text;
                }
              }
            } catch {
              // Skip malformed JSON chunks
            }
          }
        }
      }
    } catch (err) {
      if (err instanceof AuthenticationError || err instanceof RateLimitError || err instanceof ProviderError) {
        throw err;
      }
      if ((err as Error).name === 'AbortError') {
        throw new ProviderError(0, 'Gemini request timed out after 60s');
      }
      throw new ProviderError(0, `Gemini streaming failed: ${(err as Error).message}`);
    } finally {
      clearTimeout(timeout);
    }
  }

  /**
   * Checks if the Gemini service is reachable with the given config.
   */
  async getStatus(config: Record<string, unknown>): Promise<'online' | 'offline' | 'error'> {
    try {
      await this.validateConfig(config);
      return 'online';
    } catch (err) {
      if (err instanceof AuthenticationError) return 'error';
      return 'offline';
    }
  }
}
