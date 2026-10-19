import type { Order } from './order.entity';

export type BoardColumn = 'to_pay' | 'to_ship' | 'review' | 'done';

/** Groups a merchant's open orders into the dashboard board's columns. */
export function boardColumn(order: Order): BoardColumn {
  if (order.status === 'pending_payment') return 'to_pay';
  if (order.status === 'awaiting_review') return 'review';
  if (order.status === 'paid' || order.status === 'fulfilling') return 'to_ship';
  return 'done';
}
