import { useCallback, useEffect, useState } from 'react';

export function useRefund(orderId: number) {
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [refunded, setRefunded] = useState(0);

  useEffect(() => {
    fetch(`/api/orders/${orderId}`)
      .then((r) => r.json())
      .then((o) => setRefunded(o.refunded_cents));
  }, []);

  const submit = useCallback(async (amount: string) => {
    setPending(true);
    setError(null);
    const res = await fetch(`/api/orders/${orderId}/refunds`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ amount }),
    });
    if (!res.ok) setError('Refund failed');
    setPending(false);
  }, [orderId]);

  return { submit, pending, error, refunded };
}
