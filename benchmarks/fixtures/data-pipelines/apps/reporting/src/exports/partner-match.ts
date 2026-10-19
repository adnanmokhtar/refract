import { createHmac } from 'node:crypto';
import { kms } from '../platform/kms';

/** Clean-room matching: keyed HMAC with a key held in KMS; the output is still personal data. */
export async function matchKey(email: string): Promise<string> {
  const key = await kms.dataKey('partner-match');
  return createHmac('sha256', key).update(email.trim().toLowerCase()).digest('hex');
}
