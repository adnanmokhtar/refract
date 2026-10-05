'use client';

import { useEffect, useRef } from 'react';
import { api, type CartLine } from '@/lib/api';

// Mirrors the local cart to the server so it follows the customer across devices.
export function CartSync({ lines }: { lines: CartLine[] }) {
  const first = useRef(true);

  useEffect(() => {
    if (first.current) {
      first.current = false;
      return;
    }
    const id = setTimeout(() => {
      const payload = lines.map(({ productId, qty }) => ({ productId, qty }));
      void api.put('/me/cart', { lines: payload }).catch(() => undefined);
    }, 800);
    return () => clearTimeout(id);
  }, [lines]);

  return null;
}
