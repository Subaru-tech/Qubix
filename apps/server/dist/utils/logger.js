"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.loggerConfig = void 0;
exports.redact = redact;
exports.registerRedactHooks = registerRedactHooks;
const SENSITIVE_KEYS = [
    'password',
    'passwordhash',
    'clientsecret',
    'secret',
    'token',
    'authorization',
    'apikey',
    'key',
    'cookie',
    'set-cookie',
];
/**
 * Recursively redacts sensitive keys from an object or value.
 */
function redact(val) {
    if (val === null || val === undefined)
        return val;
    if (Array.isArray(val)) {
        return val.map(redact);
    }
    if (typeof val === 'object') {
        const clean = {};
        for (const key of Object.keys(val)) {
            const lowerKey = key.toLowerCase();
            if (SENSITIVE_KEYS.some((k) => lowerKey.includes(k))) {
                clean[key] = '[REDACTED]';
            }
            else {
                clean[key] = redact(val[key]);
            }
        }
        return clean;
    }
    return val;
}
/**
 * Logger configuration to pass to Fastify.
 * Serializes and redacts request/response headers, and natively redacts sensitive fields.
 */
exports.loggerConfig = {
    level: process.env.NODE_ENV === 'test' ? 'silent' : 'info',
    redact: {
        paths: [
            'req.headers.authorization',
            'req.headers.cookie',
            'req.headers["x-api-key"]',
            'body.password',
            'body.passwordhash',
            'body.clientsecret',
            'body.secret',
            'body.token',
            'body.authorization',
            'body.apikey',
            'body.key',
            'body.cookie',
            'body.set-cookie',
            'body.config.apiKey',
            'body.config.api_key',
        ],
        censor: '[REDACTED]',
    },
    serializers: {
        req(request) {
            return {
                method: request.method,
                url: request.url,
                path: request.routerPath,
                parameters: request.params,
                headers: redact(request.headers),
                remoteAddress: request.ip,
            };
        },
        res(reply) {
            return {
                statusCode: reply.statusCode,
                headers: redact(reply.getHeaders ? reply.getHeaders() : {}),
            };
        },
    },
};
/**
 * Registers global hooks to log and redact request and response bodies.
 */
function registerRedactHooks(fastify) {
    // Redact and log incoming request bodies
    fastify.addHook('preHandler', async (request) => {
        if (request.body) {
            request.log.info({ body: redact(request.body) }, 'Incoming Request Body');
        }
    });
    // Redact and log outgoing response bodies (JSON content only)
    fastify.addHook('onSend', async (request, reply, payload) => {
        try {
            const contentType = reply.getHeader('content-type');
            if (contentType && String(contentType).includes('application/json')) {
                const parsed = JSON.parse(payload);
                request.log.info({ body: redact(parsed) }, 'Outgoing Response Body');
            }
        }
        catch {
            // Ignore parser issues on non-JSON or partial streams
        }
        return payload;
    });
}
