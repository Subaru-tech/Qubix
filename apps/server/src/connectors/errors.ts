/**
 * Custom error types for the Qubix connector framework.
 * Each error extends a base ConnectorError so route handlers
 * can catch all connector failures with a single type guard.
 */

export class ConnectorError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'ConnectorError';
  }
}

export class AuthenticationError extends ConnectorError {
  constructor(message = 'Authentication failed: invalid API key or credentials') {
    super(message);
    this.name = 'AuthenticationError';
  }
}

export class RateLimitError extends ConnectorError {
  public retryAfter: number | null;

  constructor(retryAfter: number | null = null, message?: string) {
    super(message || `Rate limit exceeded${retryAfter ? `. Retry after ${retryAfter}s` : ''}`);
    this.name = 'RateLimitError';
    this.retryAfter = retryAfter;
  }
}

export class ProviderError extends ConnectorError {
  public statusCode: number;

  constructor(statusCode: number, message = 'Provider service temporarily unavailable') {
    super(message);
    this.name = 'ProviderError';
    this.statusCode = statusCode;
  }
}

export class SSRFError extends ConnectorError {
  constructor(url: string) {
    super(`Blocked request to private/internal address: ${url}`);
    this.name = 'SSRFError';
  }
}

export class WebhookTimeoutError extends ConnectorError {
  constructor(url: string, timeoutMs: number) {
    super(`Webhook timed out after ${timeoutMs}ms: ${url}`);
    this.name = 'WebhookTimeoutError';
  }
}

export class WebhookUnreachableError extends ConnectorError {
  constructor(url: string, attempts: number) {
    super(`Webhook unreachable after ${attempts} attempts: ${url}`);
    this.name = 'WebhookUnreachableError';
  }
}

export class WebhookInvalidResponseError extends ConnectorError {
  constructor(url: string, reason: string) {
    super(`Invalid webhook response from ${url}: ${reason}`);
    this.name = 'WebhookInvalidResponseError';
  }
}
