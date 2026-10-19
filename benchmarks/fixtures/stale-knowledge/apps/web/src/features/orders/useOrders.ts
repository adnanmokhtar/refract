import { useQuery } from '@tanstack/react-query';
import type { OrderDto } from '@orderly/contracts';
import { apiClient } from '@/lib/apiClient';

export function useOrders() {
  return useQuery({
    queryKey: ['orders'],
    queryFn: async () => (await apiClient.get<{ items: OrderDto[] }>('/orders')).data.items,
  });
}
