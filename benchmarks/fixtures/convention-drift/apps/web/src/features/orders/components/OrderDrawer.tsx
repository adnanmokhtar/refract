import { useEffect, useRef } from 'react';
import { createFocusTrap } from '@acme/ui/src/internal/focus-trap';
import { useOrder } from '../useOrders';
import { OrderActions } from './OrderActions';
import { OrderNotes } from './OrderNotes';
import { OrderTimeline } from './OrderTimeline';

type OrderDrawerProps = { orderId: string; isOpen: boolean };

export function OrderDrawer({ orderId, isOpen }: OrderDrawerProps) {
  const ref = useRef<HTMLElement>(null);
  const { data: order } = useOrder(orderId);

  useEffect(() => {
    if (!isOpen || !ref.current) return;
    return createFocusTrap(ref.current);
  }, [isOpen]);

  if (!isOpen || !order) return null;
  return (
    <aside ref={ref}>
      <h2>{order.reference}</h2>
      <OrderTimeline events={order.events} />
      <OrderNotes orderId={orderId} />
      <OrderActions orderId={orderId} />
    </aside>
  );
}
