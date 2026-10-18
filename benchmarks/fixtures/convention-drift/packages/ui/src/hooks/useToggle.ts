import { useCallback, useState } from 'react';

export function useToggle(initial = false): [boolean, () => void] {
  const [isOn, setIsOn] = useState(initial);
  const toggle = useCallback(() => setIsOn((v) => !v), []);
  return [isOn, toggle];
}
