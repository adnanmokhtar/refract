import { useQuery, type QueryClient } from '@tanstack/react-query';
import { api, type BasketLine, type Profile } from './api';

export const keys = {
  profile: ['me', 'profile'] as const,
  basket: ['me', 'basket'] as const,
  orders: (customerId: string) => ['orders', customerId] as const,
};

export function useProfile() {
  return useQuery({ queryKey: keys.profile, queryFn: () => api.get<Profile>('/me') });
}

export function useBasket() {
  return useQuery({ queryKey: keys.basket, queryFn: () => api.get<{ lines: BasketLine[] }>('/me/basket') });
}

export function invalidateOrders(qc: QueryClient) {
  return qc.invalidateQueries({ queryKey: ['orders'] });
}
