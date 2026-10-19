/**
 * Partner webhooks are signed over a canonical form of the JSON body: object keys sorted, no whitespace.
 * The body has already been parsed by Fastify (bodyLimit 1 MiB, api/src/main.ts).
 */
export function canonical(v: unknown): unknown {
  if (Array.isArray(v)) {
    return v.map(canonical);
  }
  if (v !== null && typeof v === 'object') {
    const out: Record<string, unknown> = {};
    for (const k of Object.keys(v as Record<string, unknown>).sort()) {
      out[k] = canonical((v as Record<string, unknown>)[k]);
    }
    return out;
  }
  return v;
}

export function canonicalString(body: unknown): string {
  return JSON.stringify(canonical(body));
}
