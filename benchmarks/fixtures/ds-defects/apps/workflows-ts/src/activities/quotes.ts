import { request } from 'undici';

const LINEHAUL = process.env.LINEHAUL_API_URL ?? 'https://api.linehaul-partner.example';

export async function bookHeldSlot(quoteId: string): Promise<void> {
  await request(`${LINEHAUL}/holds/${quoteId}/book`, { method: 'PUT' });
}

export async function releaseHeldSlot(quoteId: string): Promise<void> {
  await request(`${LINEHAUL}/holds/${quoteId}`, { method: 'DELETE' });
}
