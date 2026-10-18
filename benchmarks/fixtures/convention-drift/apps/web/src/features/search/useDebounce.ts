import { useEffect, useRef, useState } from 'react';

// Leading edge: the first change goes through at once, later ones wait for a quiet period.
export function useDebounce<T>(value: T, delayMs = 300): T {
  const [debounced, setDebounced] = useState(value);
  const isWaiting = useRef(false);
  useEffect(() => {
    if (!isWaiting.current) {
      setDebounced(value);
      isWaiting.current = true;
    }
    const id = setTimeout(() => {
      isWaiting.current = false;
      setDebounced(value);
    }, delayMs);
    return () => clearTimeout(id);
  }, [value, delayMs]);
  return debounced;
}
