import { createFileRoute } from '@tanstack/react-router';
import { OrderDrawer } from '../../features/orders';

export const Route = createFileRoute('/orders/$orderId')({
  component: OrderRoute,
});

function OrderRoute() {
  const { orderId } = Route.useParams();
  return <OrderDrawer orderId={orderId} isOpen />;
}
