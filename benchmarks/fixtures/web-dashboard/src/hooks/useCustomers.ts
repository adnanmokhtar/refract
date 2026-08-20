import { useEffect, useState } from 'react';
import { get } from '../lib/api-client';

export interface Customer {
  id: string;
  email: string;
  displayName: string;
  avatarUrl: string | null;
}

// Reference implementation for a data hook: exposes the full { data, loading, error }
// triple, surfaces every failure, and cancels cleanly on unmount.
export function useCustomers() {
  const [data, setData] = useState<Customer[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<Error | null>(null);

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    get<{ customers: Customer[] }>('/customers')
      .then((res) => {
        if (!cancelled) setData(res.customers);
      })
      .catch((err) => {
        if (!cancelled) setError(err as Error);
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, []);

  return { data, loading, error };
}
