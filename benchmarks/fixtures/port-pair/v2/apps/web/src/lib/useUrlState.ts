import { useCallback, useMemo } from 'react';
import { useSearchParams } from 'react-router';

// Page state that survives Back, reload and a shared link, the way V1's GET filter forms did.
// The value is memoised on the query string, so it is stable across renders (safe as an effect dependency).
export function useUrlState<T extends string | string[]>(key: string, fallback: T): [T, (next: T) => void] {
  const [params, setParams] = useSearchParams();
  const raw = params.toString();
  const isList = Array.isArray(fallback);
  const value = useMemo(() => {
    const read = new URLSearchParams(raw);
    if (isList) {
      const all = read.getAll(key);
      return (all.length ? all : []) as T;
    }
    return (read.get(key) ?? fallback) as T;
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [raw, key, isList]);

  const set = useCallback(
    (next: T) => {
      const copy = new URLSearchParams(raw);
      copy.delete(key);
      for (const v of Array.isArray(next) ? next : [next]) {
        copy.append(key, v);
      }
      setParams(copy);
    },
    [raw, key, setParams],
  );

  return [value, set];
}
