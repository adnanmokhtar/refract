import { roundHalfAwayFromZero } from '../money/money-policy';
import type { Order } from './order.entity';

/** The order-level discount in minor units, as checkout stored it. */
export function orderDiscountMinor(order: Order): number {
  if (!order.discountType || order.discountValue == null) return 0;
  if (order.discountType === 'percentage') {
    return roundHalfAwayFromZero((order.subtotalMinor * order.discountValue) / 100);
  }
  return order.discountValue;
}
