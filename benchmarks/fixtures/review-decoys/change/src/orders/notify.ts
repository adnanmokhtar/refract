import { withRetry } from '../lib/retry';

export async function notifyCustomer(orderId: number, refundId: number): Promise<void> {
  const res = await withRetry(() =>
    fetch(`${process.env.MAILER_URL}/refund-issued`, {
      method: 'POST',
      headers: { 'content-type': 'application/json', 'idempotency-key': `refund-${refundId}` },
      body: JSON.stringify({ orderId, refundId }),
      signal: AbortSignal.timeout(3000),
    }),
  );
  if (!res.ok) throw new Error(`mailer ${res.status}`);
}
