import { env } from '../env.js';

export interface CaptureResult {
  captureId: string;
  status: 'captured' | 'pending';
}

/** Re-submits a capture to the PSP (support console). */
export async function capturePayment(paymentId: string): Promise<CaptureResult> {
  const res = await fetch(`${env.PSP_BASE_URL}/v2/payments/${paymentId}/capture`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ reason: 'console-retry' }),
    signal: AbortSignal.timeout(8000),
  });
  if (!res.ok) throw Object.assign(new Error('psp capture failed'), { response: { status: res.status } });
  return (await res.json()) as CaptureResult;
}
