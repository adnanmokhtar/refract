import { createHmac, timingSafeEqual } from 'node:crypto';

export function verifyWebhookSignature(payload: string, header: string, secret: string): boolean {
  const parts = Object.fromEntries(header.split(',').map((kv) => kv.split('=') as [string, string]));
  if (!parts.t || !parts.v1) return false;
  const expected = createHmac('sha256', secret).update(`${parts.t}.${payload}`).digest();
  const given = Buffer.from(parts.v1, 'hex');
  return given.length === expected.length && timingSafeEqual(given, expected);
}
