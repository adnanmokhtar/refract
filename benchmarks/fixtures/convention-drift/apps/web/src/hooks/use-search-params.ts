import { useCallback, useState } from 'react';

export function useSearchParams(): [URLSearchParams, (next: Record<string, string>) => void] {
  const [params, setParams] = useState(() => new URLSearchParams(window.location.search));
  const update = useCallback((next: Record<string, string>) => {
    const p = new URLSearchParams(next);
    window.history.replaceState(null, '', `?${p.toString()}`);
    setParams(p);
  }, []);
  return [params, update];
}
