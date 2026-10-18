import { useQuery } from '@tanstack/react-query';
import { apiClient } from '@acme/http';

type PastOrder = { id: string; createdAt: string; totalMinor: number; currency: string };

export function useOrderHistory(customerId: string) {
  return useQuery({
    queryKey: ['history', customerId],
    queryFn: () => apiClient.get(`customers/${customerId}/orders`).json<PastOrder[]>(),
  });
}
