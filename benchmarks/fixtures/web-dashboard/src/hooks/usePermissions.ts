import { useEffect, useState } from 'react';
import { get } from '../lib/api-client';

// Permission list for the signed-in user. Cached for the session.
export function usePermissions() {
  const [allowed, setAllowed] = useState<string[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<Error | null>(null);

  useEffect(() => {
    let cancelled = false;
    get<{ actions: string[] }>('/me/permissions')
      .then((res) => {
        if (!cancelled) setAllowed(res.actions);
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

  return { allowed, loading, error };
}
