"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.WebhookConnector = void 0;
const crypto_1 = require("crypto");
const promises_1 = __importDefault(require("dns/promises"));
const base_1 = require("./base");
const errors_1 = require("./errors");
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
function ipToInt(ip) {
    const parts = ip.split('.').map(Number);
    return ((parts[0] << 24) | (parts[1] << 16) | (parts[2] << 8) | parts[3]) >>> 0;
}
function isPrivateIP(ip) {
    const num = ipToInt(ip);
    return PRIVATE_RANGES.some((range) => num >= range.start && num <= range.end);
}
const BLOCKED_HOSTNAMES = ['localhost', 'localhost.localdomain', '0.0.0.0'];
async function validateUrlSafety(urlStr) {
    let parsed;
    try {
        parsed = new URL(urlStr);
    }
    catch {
        throw new errors_1.SSRFError(urlStr);
    }
    // Only allow http/https
    if (!['http:', 'https:'].includes(parsed.protocol)) {
        throw new errors_1.SSRFError(urlStr);
    }
    const hostname = parsed.hostname;
    // Block known internal hostnames
    if (BLOCKED_HOSTNAMES.includes(hostname.toLowerCase())) {
        throw new errors_1.SSRFError(urlStr);
    }
    // Check if hostname is an IP literal
    const ipv4Regex = /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/;
    if (ipv4Regex.test(hostname)) {
        if (isPrivateIP(hostname)) {
            throw new errors_1.SSRFError(urlStr);
        }
        return parsed;
    }
    // Resolve hostname and check all IPs
    try {
        const addresses = await promises_1.default.resolve4(hostname);
        for (const addr of addresses) {
            if (isPrivateIP(addr)) {
                throw new errors_1.SSRFError(urlStr);
            }
        }
    }
    catch (err) {
        if (err instanceof errors_1.SSRFError)
            throw err;
        // DNS resolution failure — allow and let fetch handle it
    }
    return parsed;
}
function parseConfig(config) {
    const url = config.url;
    if (!url || typeof url !== 'string' || url.trim() === '') {
        throw new errors_1.WebhookInvalidResponseError('(no url)', 'missing required field "url"');
    }
    return {
        url,
        headers: config.headers || undefined,
    };
}
function sleep(ms) {
    return new Promise((resolve) => setTimeout(resolve, ms));
}
class WebhookConnector extends base_1.BaseConnector {
    /**
     * Validates the webhook URL format and checks SSRF safety.
     */
    async validateConfig(config) {
        const parsed = parseConfig(config);
        await validateUrlSafety(parsed.url);
        return true;
    }
    /**
     * Sends a POST request to the webhook URL with the message payload.
     * Retries twice on network failure with 5s delay between attempts.
     * Yields the response content as a single chunk (webhooks don't stream).
     */
    async *sendMessage(params) {
        const parsed = parseConfig(params.config);
        await validateUrlSafety(parsed.url);
        const lastMessage = params.messages[params.messages.length - 1];
        const payload = {
            threadId: params.threadId,
            messageId: (0, crypto_1.randomUUID)(),
            content: lastMessage?.content || '',
            history: params.messages.slice(-20),
            timestamp: new Date().toISOString(),
        };
        const maxAttempts = 3;
        let lastError = null;
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
                let body;
                try {
                    body = await res.json();
                }
                catch {
                    throw new errors_1.WebhookInvalidResponseError(parsed.url, 'response is not valid JSON');
                }
                if (!body || typeof body.content !== 'string') {
                    throw new errors_1.WebhookInvalidResponseError(parsed.url, 'response missing required "content" string field');
                }
                yield body.content;
                return;
            }
            catch (err) {
                clearTimeout(timeout);
                // Don't retry validation/response format errors
                if (err instanceof errors_1.WebhookInvalidResponseError || err instanceof errors_1.SSRFError) {
                    throw err;
                }
                if (err.name === 'AbortError') {
                    throw new errors_1.WebhookTimeoutError(parsed.url, 30_000);
                }
                lastError = err;
                if (attempt < maxAttempts) {
                    await sleep(5_000);
                }
            }
            finally {
                clearTimeout(timeout);
            }
        }
        throw new errors_1.WebhookUnreachableError(parsed.url, maxAttempts);
    }
    /**
     * Checks if the webhook URL is reachable via a HEAD request.
     */
    async getStatus(config) {
        const parsed = parseConfig(config);
        try {
            await validateUrlSafety(parsed.url);
        }
        catch {
            return 'error';
        }
        const controller = new AbortController();
        const timeout = setTimeout(() => controller.abort(), 10_000);
        try {
            const res = await fetch(parsed.url, {
                method: 'HEAD',
                signal: controller.signal,
            });
            if (res.ok)
                return 'online';
            if (res.status >= 400 && res.status < 500)
                return 'error';
            return 'offline';
        }
        catch {
            return 'offline';
        }
        finally {
            clearTimeout(timeout);
        }
    }
}
exports.WebhookConnector = WebhookConnector;
