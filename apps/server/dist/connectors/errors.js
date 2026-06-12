"use strict";
/**
 * Custom error types for the Qubix connector framework.
 * Each error extends a base ConnectorError so route handlers
 * can catch all connector failures with a single type guard.
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.WebhookInvalidResponseError = exports.WebhookUnreachableError = exports.WebhookTimeoutError = exports.SSRFError = exports.ProviderError = exports.RateLimitError = exports.AuthenticationError = exports.ConnectorError = void 0;
class ConnectorError extends Error {
    constructor(message) {
        super(message);
        this.name = 'ConnectorError';
    }
}
exports.ConnectorError = ConnectorError;
class AuthenticationError extends ConnectorError {
    constructor(message = 'Authentication failed: invalid API key or credentials') {
        super(message);
        this.name = 'AuthenticationError';
    }
}
exports.AuthenticationError = AuthenticationError;
class RateLimitError extends ConnectorError {
    retryAfter;
    constructor(retryAfter = null, message) {
        super(message || `Rate limit exceeded${retryAfter ? `. Retry after ${retryAfter}s` : ''}`);
        this.name = 'RateLimitError';
        this.retryAfter = retryAfter;
    }
}
exports.RateLimitError = RateLimitError;
class ProviderError extends ConnectorError {
    statusCode;
    constructor(statusCode, message = 'Provider service temporarily unavailable') {
        super(message);
        this.name = 'ProviderError';
        this.statusCode = statusCode;
    }
}
exports.ProviderError = ProviderError;
class SSRFError extends ConnectorError {
    constructor(url) {
        super(`Blocked request to private/internal address: ${url}`);
        this.name = 'SSRFError';
    }
}
exports.SSRFError = SSRFError;
class WebhookTimeoutError extends ConnectorError {
    constructor(url, timeoutMs) {
        super(`Webhook timed out after ${timeoutMs}ms: ${url}`);
        this.name = 'WebhookTimeoutError';
    }
}
exports.WebhookTimeoutError = WebhookTimeoutError;
class WebhookUnreachableError extends ConnectorError {
    constructor(url, attempts) {
        super(`Webhook unreachable after ${attempts} attempts: ${url}`);
        this.name = 'WebhookUnreachableError';
    }
}
exports.WebhookUnreachableError = WebhookUnreachableError;
class WebhookInvalidResponseError extends ConnectorError {
    constructor(url, reason) {
        super(`Invalid webhook response from ${url}: ${reason}`);
        this.name = 'WebhookInvalidResponseError';
    }
}
exports.WebhookInvalidResponseError = WebhookInvalidResponseError;
