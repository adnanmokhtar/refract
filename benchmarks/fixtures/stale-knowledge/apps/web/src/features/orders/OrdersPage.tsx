import { OrderTable } from '@/components/OrderTable';
import { useOrders } from './useOrders';

export function OrdersPage() {
  const { data, isPending, error } = useOrders();
  if (isPending) return <p>Loading orders</p>;
  if (error) return <p role="alert">Orders could not be loaded.</p>;
  return <OrderTable orders={data} />;
}
