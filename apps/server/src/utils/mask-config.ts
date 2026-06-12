/**
 * Recursively masks sensitive fields in configuration objects.
 * Any key (case-insensitive) containing "key", "token", "secret",
 * "password", or "auth" gets its value replaced with "***".
 */

const SENSITIVE_PATTERNS = /key|token|secret|password|auth/i;

export function maskConfig(obj: Record<string, unknown>): Record<string, unknown> {
  const masked: Record<string, unknown> = {};

  for (const [key, value] of Object.entries(obj)) {
    if (SENSITIVE_PATTERNS.test(key)) {
      masked[key] = '***';
    } else if (value && typeof value === 'object' && !Array.isArray(value)) {
      masked[key] = maskConfig(value as Record<string, unknown>);
    } else if (Array.isArray(value)) {
      masked[key] = value.map((item) => {
        if (item && typeof item === 'object' && !Array.isArray(item)) {
          return maskConfig(item as Record<string, unknown>);
        }
        return item;
      });
    } else {
      masked[key] = value;
    }
  }

  return masked;
}
