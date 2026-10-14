import { ApplicationFailure } from '@temporalio/activity';
import { request } from 'undici';

const LINEHAUL = process.env.LINEHAUL_API_URL ?? 'https://api.linehaul-partner.example';

export async function reserveTrailerCapacity(fromDepot: string, toDepot: string): Promise<void> {
  const res = await request(`${LINEHAUL}/capacity/${fromDepot}/${toDepot}/hold`, { method: 'PUT' });
  if (res.statusCode === 404) throw ApplicationFailure.nonRetryable(`no lane ${fromDepot}->${toDepot}`);
}

/** Each POST books (and bills) one pallet position on tonight's trailer; the partner has no idempotency key. */
export async function bookLinehaul(palletId: string, fromDepot: string, toDepot: string): Promise<string> {
  const res = await request(`${LINEHAUL}/bookings`, {
    method: 'POST',
    body: JSON.stringify({ palletRef: palletId, from: fromDepot, to: toDepot }),
    headers: { 'content-type': 'application/json' },
  });
  if (res.statusCode >= 500) throw new Error(`linehaul partner ${res.statusCode}`);
  return ((await res.body.json()) as { bookingId: string }).bookingId;
}
