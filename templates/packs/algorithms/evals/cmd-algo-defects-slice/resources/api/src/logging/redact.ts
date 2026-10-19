/**
 * Redacts secrets from objects before they are logged. Any object can reach the logger (errors carry
 * `cause` chains, entities carry back-references), so the walk caps depth and tracks the current path.
 */
const MAX_DEPTH = 8;
const SECRET_KEYS = new Set(['password', 'token', 'authorization', 'cardNumber', 'cvc', 'otp']);

export function redact(value: unknown, depth = 0, ancestors: Set<object> = new Set()): unknown {
  if (value === null || typeof value !== 'object') {
    return value;
  }
  if (depth > MAX_DEPTH) {
    return '[depth]';
  }
  if (ancestors.has(value)) {
    return '[circular]';
  }
  ancestors.add(value);
  try {
    if (Array.isArray(value)) {
      return value.map((v) => redact(v, depth + 1, ancestors));
    }
    const out: Record<string, unknown> = {};
    for (const [k, v] of Object.entries(value)) {
      out[k] = SECRET_KEYS.has(k) ? '[redacted]' : redact(v, depth + 1, ancestors);
    }
    return out;
  } finally {
    ancestors.delete(value);
  }
}
