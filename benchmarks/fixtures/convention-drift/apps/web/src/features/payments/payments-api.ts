import { apiClient } from '@acme/http';
import { backoffMs } from '../../../../../packages/http/src/retry';

export type PaymentMethod = { id: string; brand: string; last4: string };

export async function fetchPaymentMethods(attempt = 0): Promise<PaymentMethod[]> {
  try {
    return await apiClient.get('payment-methods').json<PaymentMethod[]>();
  } catch (error) {
    if (attempt >= 2) throw error;
    await new Promise((resolve) => setTimeout(resolve, backoffMs(attempt)));
    return fetchPaymentMethods(attempt + 1);
  }
}
