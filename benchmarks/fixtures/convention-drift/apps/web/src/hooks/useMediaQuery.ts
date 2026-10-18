import { useEffect, useState } from 'react';

export function useMediaQuery(query: string): boolean {
  const [isMatch, setIsMatch] = useState(() => window.matchMedia(query).matches);
  useEffect(() => {
    const list = window.matchMedia(query);
    const onChange = () => setIsMatch(list.matches);
    list.addEventListener('change', onChange);
    return () => list.removeEventListener('change', onChange);
  }, [query]);
  return isMatch;
}
