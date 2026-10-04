import { useEffect, useState } from 'react';

export function useRefundHistory(orderId: number) {
  const [history, setHistory] = useState<Array<{ id: number; amount_cents: number }>>([]);

  useEffect(() => {
    const ctrl = new AbortController();
    fetch(`/api/orders/${orderId}/refunds`, { signal: ctrl.signal })
      .then((r) => r.json())
      .then(setHistory)
      .catch((e: Error) => {
        if (e.name !== 'AbortError') reportError(e);
      });
    return () => ctrl.abort();
  }, [orderId]);

  return history;
}
