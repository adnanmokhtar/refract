import { useMutation } from '@tanstack/react-query';
import { apiClient } from '@acme/http';

export function useRequestRefund() {
  return useMutation({
    mutationFn: (body: { orderId: string; amountMinor: number }) => apiClient.post('refunds', { json: body }).json(),
  });
}
