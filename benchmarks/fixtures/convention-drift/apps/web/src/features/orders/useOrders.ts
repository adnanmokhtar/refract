import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { apiClient } from '@acme/http';
import { fetchOrder, fetchOrders } from './api';

export function useOrders() {
  return useQuery({ queryKey: ['orders'], queryFn: () => fetchOrders() });
}

export function useOrder(id: string) {
  return useQuery({ queryKey: ['orders', id], queryFn: () => fetchOrder(id) });
}

function useOrderMutation(path: (id: string) => string, method: 'post' | 'delete') {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (id: string) => apiClient(path(id), { method }).json(),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['orders'] }),
  });
}

export const useDeleteOrder = () => useOrderMutation((id) => `orders/${id}`, 'delete');
export const useArchiveOrder = () => useOrderMutation((id) => `orders/${id}/archive`, 'post');
export const useCancelOrder = () => useOrderMutation((id) => `orders/${id}/cancel`, 'post');
