import { apiFetch } from './http';

/** Applies a campaign code to the signed-in customer's next order. */
export function applyPromoCode(code: string) {
  return apiFetch<{ discountCents: number }>('/me/promotions', {
    method: 'POST',
    body: JSON.stringify({ code }),
  });
}
