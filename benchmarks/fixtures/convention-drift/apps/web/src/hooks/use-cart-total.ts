import { useMemo } from 'react';

export function useCartTotal(items: Array<{ priceMinor: number; quantity: number }>, currency: string): [number, string] {
  const total = useMemo(() => items.reduce((sum, i) => sum + i.priceMinor * i.quantity, 0), [items]);
  return [total, currency];
}
