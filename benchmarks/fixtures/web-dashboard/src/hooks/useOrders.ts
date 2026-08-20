import { useEffect, useState } from 'react';
import { get } from '../lib/api-client';

export interface Order {
  id: string;
  reference: string;
  customerEmail: string;
  status: string;
  totalCents: number;
}

export function useOrders(status: string) {
  const [data, setData] = useState<Order[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<Error | null>(null);

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    get<{ orders: Order[] }>(`/orders?status=${status}`)
      .then((res) => {
        if (!cancelled) setData(res.orders);
      })
      .catch(() => {
        if (!cancelled) setData([]);
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, [status]);

  return { data, loading, error };
}
