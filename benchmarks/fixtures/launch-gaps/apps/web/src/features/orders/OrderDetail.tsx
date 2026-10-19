import { useParams } from 'react-router';
import { useMutation, useQuery } from '@tanstack/react-query';
import { http } from '../../shared/api/http';
import { useCan } from '../../entities/permissions/use-permissions';
import { Button } from '../../components/Button';

interface Order {
  id: string;
  number: string;
  lines: { id: string; sku: string; qty: number; totalCents: number }[];
  status: string;
}

export function OrderDetail() {
  const { orderId = '' } = useParams();
  const canRefund = useCan('orders.refund');
  const order = useQuery({ queryKey: ['order', orderId], queryFn: () => http.get(`orders/${orderId}`).json<Order>() });
  const refund = useMutation({
    mutationFn: (lines: string[]) => http.post(`orders/${orderId}/refunds`, { json: { lines, reason: 'merchant' } }).json(),
  });

  async function downloadInvoice() {
    const res = await fetch(`/api/orders/${orderId}/invoice`, { credentials: 'include' });
    const blob = await res.blob();
    window.open(URL.createObjectURL(blob), '_blank');
  }

  if (!order.data) return null;
  return (
    <section>
      <h1>Order {order.data.number}</h1>
      <Button variant="secondary" onClick={() => void downloadInvoice()}>
        Download invoice
      </Button>
      {canRefund && (
        <Button variant="danger" onClick={() => refund.mutate(order.data!.lines.map((l) => l.id))}>
          Refund all
        </Button>
      )}
    </section>
  );
}
