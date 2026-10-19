import type { OrderLine } from '../orders/order-line.entity';

/** The amount a return of a whole line gives back (used by the returns desk). */
export function returnedLineMinor(line: OrderLine): number {
  return line.product.price * line.quantity;
}
