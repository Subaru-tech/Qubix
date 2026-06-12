import { randomUUID } from 'crypto';
import dns from 'dns/promises';
import { BaseConnector } from './base';
import {
  SSRFError,
  WebhookTimeoutError,
  WebhookUnreachableError,
  WebhookInvalidResponseError,
} from './errors';

interface WebhookConfig {
  url: string;
  headers?: Record<string, string>;
}

/**
 * Private IP ranges that must be blocked to prevent SSRF attacks.
 */
const PRIVATE_RANGES = [
  // 10.0.0.0/8
  { start: 0x0a000000, end: 0x0affffff },
  // 172.16.0.0/12
  { start: 0xac100000, end: 0xac1fffff },
  // 192.168.0.0/16
  { start: 0xc0a80000, end: 0xc0a8ffff },
  // 127.0.0.0/8
  { start: 0x7f000000, end: 0x7fffffff },
  // 0.0.0.0/8
  { start: 0x00000000, end: 0x00ffffff },
  // 169.254.0.0/16 (link-local)
  { start: 0xa9fe0000, end: 0xa9feffff },
];

function ipToInt(ip: string): number {
  const parts = ip.split('.').map(Number);
  return ((parts[0] << 24) | (parts[1] << 16) | (parts[2] << 8) | parts[3]) >>> 0;
}

function isPrivateIP(ip: string): boolean {
  const num = ipToInt(ip);
  return PRIVATE_RANGES.some((range) => num >= range.start && num <= range.end);
}

const BLOCKED_HOSTNAMES = ['localhost', 'localhost.localdomain', '0.0.0.0'];

async function validateUrlSafety(urlStr: string): Promise<URL> {
  let parsed: URL;
  try {
    parsed = new URL(urlStr);
  } catch {
    throw new SSRFError(urlStr);
  }

  // Only allow http/https
  if (!['http:', 'https:'].includes(parsed.protocol)) {
    throw new SSRFError(urlStr);
  }

  const hostname = parsed.hostname;

  // Block known internal hostnames
  if (BLOCKED_HOSTNAMES.includes(hostname.toLowerCase())) {
    throw new SSRFError(urlStr);
  }

  // Check if hostname is an IP literal
  const ipv4Regex = /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/;
  if (ipv4Regex.test(hostname)) {
    if (isPrivateIP(hostname)) {
      throw new SSRFError(urlStr);
    }
    return parsed;
  }

  // Resolve hostname and check all IPs
  try {
    const addresses = await dns.resolve4(hostname);
    for (const addr of addresses) {
      if (isPrivateIP(addr)) {
        throw new SSRFError(urlStr);
      }
    }
  } catch (err) {
    if (err instanceof SSRFError) throw err;
    // DNS resolution failure — allow and let fetch handle it
  }

  return parsed;
}

function parseConfig(config: Record<string, unknown>): WebhookConfig {
  const url = config.url as string | undefined;
  if (!url || typeof url !== 'string' || url.trim() === '') {
    throw new WebhookInvalidResponseError('(no url)', 'missing required field "url"');
  }
  return {
    url,
    headers: (config.headers as Record<string, string>) || undefined,
  };
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

export class WebhookConnector extends BaseConnector {
  /**
   * Validates the webhook URL format and checks SSRF safety.
   */
  async validateConfig(config: Record<string, unknown>): Promise<boolean> {
    const parsed = parseConfig(config);
    await validateUrlSafety(parsed.url);
    return true;
  }

  /**
   * Sends a POST request to the webhook URL with the message payload.
   * Retries twice on network failure with 5s delay between attempts.
   * Yields the response content as a single chunk (webhooks don't stream).
   */
  async *sendMessage(params: {
    messages: Array<{ role: string; content: string }>;
    threadId: string;
    config: Record<string, unknown>;
  }): AsyncIterable<string> {
    const parsed = parseConfig(params.config);
    await validateUrlSafety(parsed.url);

    const lastMessage = params.messages[params.messages.length - 1];
    const payload = {
      threadId: params.threadId,
      messageId: randomUUID(),
      content: lastMessage?.content || '',
      history: params.messages.slice(-20),
      timestamp: new Date().toISOString(),
    };

    const maxAttempts = 3;
    let lastError: Error | null = null;

    for (let attempt = 1; attempt <= maxAttempts; attempt++) {
      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), 30_000);

      try {
        const res = await fetch(parsed.url, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            ...(parsed.headers || {}),
          },
          body: JSON.stringify(payload),
          signal: controller.signal,
        });

        if (!res.ok) {
          throw new Error(`HTTP ${res.status}: ${res.statusText}`);
        }

        let body: any;
        try {
          body = await res.json();
        } catch {
          throw new WebhookInvalidResponseError(parsed.url, 'response is not valid JSON');
        }

        if (!body || typeof body.content !== 'string') {
          throw new WebhookInvalidResponseError(
            parsed.url,
            'response missing required "content" string field'
          );
        }

        yield body.content;
        return;
      } catch (err) {
        clearTimeout(timeout);

        // Don't retry validation/response format errors
        if (err instanceof WebhookInvalidResponseError || err instanceof SSRFError) {
          throw err;
        }

        if ((err as Error).name === 'AbortError') {
          throw new WebhookTimeoutError(parsed.url, 30_000);
        }

        lastError = err as Error;

        if (attempt < maxAttempts) {
          await sleep(5_000);
        }
      } finally {
        clearTimeout(timeout);
      }
    }

    throw new WebhookUnreachableError(parsed.url, maxAttempts);
  }

  /**
   * Checks if the webhook URL is reachable via a HEAD request.
   */
  async getStatus(config: Record<string, unknown>): Promise<'online' | 'offline' | 'error'> {
    const parsed = parseConfig(config);

    try {
      await validateUrlSafety(parsed.url);
    } catch {
      return 'error';
    }

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 10_000);

    try {
      const res = await fetch(parsed.url, {
        method: 'HEAD',
        signal: controller.signal,
      });

      if (res.ok) return 'online';
      if (res.status >= 400 && res.status < 500) return 'error';
      return 'offline';
    } catch {
      return 'offline';
    } finally {
      clearTimeout(timeout);
    }
  }
}
