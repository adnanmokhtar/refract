import { ApplicationFailure } from '@temporalio/activity';
import { request } from 'undici';

const API = process.env.FULFILMENT_API_URL ?? 'http://api.fulfilment.svc:3000';

export async function allocateStock(ref: string): Promise<boolean> {
  const res = await request(`${API}/internal/allocations/${ref}`, { method: 'PUT' });
  if (res.statusCode === 409) return false;
  if (res.statusCode === 422) throw ApplicationFailure.nonRetryable(`allocation rejected for ${ref}`);
  return true;
}

export async function createPickList(orderId: string): Promise<string> {
  const res = await request(`${API}/internal/pick-lists/by-order/${orderId}`, { method: 'PUT' });
  return ((await res.body.json()) as { id: string }).id;
}

export async function notifyWarehouse(orderId: string, pickListId: string): Promise<void> {
  await request(`${API}/internal/warehouse-notifications/${orderId}`, { method: 'PUT', body: JSON.stringify({ pickListId }) });
}

export async function requestCarrierPickup(orderId: string, parcels: number): Promise<void> {
  await request(`${API}/internal/pickups/by-order/${orderId}`, { method: 'PUT', body: JSON.stringify({ parcels }) });
}

export async function markOrderShipped(orderId: string): Promise<void> {
  await request(`${API}/internal/orders/${orderId}/shipped`, { method: 'PUT' });
}

export async function recomputeMerchantTier(merchantId: string): Promise<void> {
  await request(`${API}/internal/merchants/${merchantId}/tier`, { method: 'PUT' });
}
