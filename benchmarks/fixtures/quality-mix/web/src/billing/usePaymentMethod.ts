import { useState } from 'react';
import { apiOrThrow } from '../api/client';

// "Update card" on the billing page. While saving, the Save button is disabled.
export function usePaymentMethod(customerId: string) {
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function save(paymentMethodToken: string): Promise<void> {
    setSaving(true);
    setError(null);
    await apiOrThrow(`/customers/${customerId}/payment-method`, {
      method: 'PUT',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ token: paymentMethodToken }),
    });
    setSaving(false);
  }

  return { saving, error, save };
}
