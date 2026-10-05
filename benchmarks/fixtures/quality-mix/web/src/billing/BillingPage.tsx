import { useState } from 'react';
import { usePaymentMethod } from './usePaymentMethod';
import { amountInputToCents } from './money';
import { toApiError } from '../api/client';
import { withRetry } from '../api/retry';

export function BillingPage({ customerId }: { customerId: string }) {
  const { saving, error, save } = usePaymentMethod(customerId);
  const [credit, setCredit] = useState('');
  const [creditError, setCreditError] = useState<string | null>(null);

  async function applyCredit() {
    const res = await withRetry(() =>
      fetch(`/api/customers/${customerId}/credit`, {
        method: 'POST',
        credentials: 'include',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ amountCents: amountInputToCents(credit) }),
      }),
    );
    if (!res.ok) throw await toApiError(res);
  }

  return (
    <section>
      <button disabled={saving} onClick={() => void save('tok_from_card_element')}>
        Save card
      </button>
      {error && <p role="alert">{error}</p>}
      <input aria-label="Apply account credit" value={credit} onChange={(e) => setCredit(e.target.value)} />
      <button onClick={() => applyCredit().catch((e: Error) => setCreditError(e.message))}>Apply credit</button>
      {creditError && <p role="alert">{creditError}</p>}
    </section>
  );
}
