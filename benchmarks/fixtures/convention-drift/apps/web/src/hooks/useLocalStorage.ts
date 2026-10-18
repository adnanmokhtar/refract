import { useState } from 'react';

export function useLocalStorage(key: string, initial: string): [string, (next: string) => void] {
  const [value, setValue] = useState(() => localStorage.getItem(key) ?? initial);
  function update(next: string) {
    localStorage.setItem(key, next);
    setValue(next);
  }
  return [value, update];
}
