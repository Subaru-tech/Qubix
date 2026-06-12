"use strict";
/**
 * Recursively masks sensitive fields in configuration objects.
 * Any key (case-insensitive) containing "key", "token", "secret",
 * "password", or "auth" gets its value replaced with "***".
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.maskConfig = maskConfig;
const SENSITIVE_PATTERNS = /key|token|secret|password|auth/i;
function maskConfig(obj) {
    const masked = {};
    for (const [key, value] of Object.entries(obj)) {
        if (SENSITIVE_PATTERNS.test(key)) {
            masked[key] = '***';
        }
        else if (value && typeof value === 'object' && !Array.isArray(value)) {
            masked[key] = maskConfig(value);
        }
        else if (Array.isArray(value)) {
            masked[key] = value.map((item) => {
                if (item && typeof item === 'object' && !Array.isArray(item)) {
                    return maskConfig(item);
                }
                return item;
            });
        }
        else {
            masked[key] = value;
        }
    }
    return masked;
}
