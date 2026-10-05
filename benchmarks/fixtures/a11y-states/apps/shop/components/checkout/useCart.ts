import { useSuspenseQuery } from '@tanstack/react-query';
import { api, type CartLine } from '@/lib/api';

export type Cart = { id: string; lines: CartLine[]; subtotal: number };

export function useCart() {
  const { data } = useSuspenseQuery({ queryKey: ['me', 'cart'], queryFn: () => api.get<Cart>('/me/cart') });
  return { cart: data };
}
