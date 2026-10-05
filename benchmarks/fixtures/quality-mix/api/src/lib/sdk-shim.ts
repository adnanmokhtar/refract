// The payment provider's SDK ships `request(opts: any): any` in its typings; we narrow it here once.
import type { ProviderCharge } from '../billing/provider.client';

interface LegacySdk {
  request(opts: unknown): Promise<unknown>;
}

export async function legacyCharge(sdk: LegacySdk, body: Record<string, unknown>): Promise<ProviderCharge> {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any -- vendor typings return any for every call; upstream issue tollgate#123, removed when SDK v9 lands
  const raw: any = await sdk.request({ method: 'POST', path: '/v1/charges', body });
  return { id: String(raw.id), status: raw.status === 'succeeded' ? 'succeeded' : 'failed', amountCents: Number(raw.amount) };
}
