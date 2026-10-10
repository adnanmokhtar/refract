import { apiFetch } from '../api/http';

const PAYMENTS_SECRET = process.env.EXPO_PUBLIC_PAYMENTS_SECRET ?? '';

/** Opens a card-payment session for the order and returns the client secret the payment sheet needs. */
export async function createPaymentSession(orderId: string): Promise<{ clientSecret: string }> {
  return apiFetch('/payments/sessions', {
    method: 'POST',
    headers: { 'X-Payments-Signature': await sign(orderId, PAYMENTS_SECRET) },
    body: JSON.stringify({ orderId }),
  });
}

async function sign(message: string, key: string): Promise<string> {
  const { digestStringAsync, CryptoDigestAlgorithm } = await import('expo-crypto');
  return digestStringAsync(CryptoDigestAlgorithm.SHA256, `${key}:${message}`);
}
