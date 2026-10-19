import { useMutation, useQueryClient } from '@tanstack/react-query';
import { http } from '../../shared/api/http';
import { useTracking } from '../../shared/tracking/TrackingProvider';

export interface OrderDraft {
  lines: { sku: string; qty: number }[];
  customerId?: string;
}

/** A manual order taken at the counter. The event fires once the API has stored the order. */
export function usePlaceOrder() {
  const qc = useQueryClient();
  const { trackEvent } = useTracking();
  return useMutation({
    mutationFn: (draft: OrderDraft) => http.post('orders', { json: draft }).json<{ id: string; totalCents: number }>(),
    onSuccess: (order) => {
      trackEvent('Order Placed', { order_id: order.id, value: order.totalCents / 100 });
      void qc.invalidateQueries({ queryKey: ['orders'] });
    },
  });
}
