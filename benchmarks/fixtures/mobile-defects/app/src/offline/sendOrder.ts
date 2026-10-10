import { v4 as uuid } from 'uuid';

import { apiFetch } from '../api/http';
import type { DraftOrder } from '../state/order';

const MAX_RETRIES = 3;

const wait = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

/** Places the order from the checkout button, retrying a dropped connection at the customer's door. */
export async function sendOrder(order: DraftOrder): Promise<{ id: string }> {
  let lastError: unknown;
  for (let attempt = 0; attempt < MAX_RETRIES; attempt++) {
    try {
      return await apiFetch<{ id: string }>('/orders', {
        method: 'POST',
        headers: { 'Idempotency-Key': uuid() },
        body: JSON.stringify(order),
      });
    } catch (error) {
      lastError = error;
      await wait(2 ** attempt * 500);
    }
  }
  throw lastError;
}
