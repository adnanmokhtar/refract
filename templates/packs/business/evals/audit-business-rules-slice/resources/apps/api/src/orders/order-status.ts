export const ORDER_STATUSES = [
  'pending_payment',
  'paid',
  'fulfilling',
  'shipped',
  'delivered',
  'cancelled',
  'refunded',
  'disputed',
  'awaiting_review',
] as const;

export type OrderStatus = (typeof ORDER_STATUSES)[number];

export const ORDER_TRANSITIONS: Partial<Record<OrderStatus, OrderStatus[]>> = {
  pending_payment: ['paid', 'cancelled'],
  paid: ['fulfilling', 'cancelled', 'disputed'],
  fulfilling: ['shipped', 'cancelled'],
  shipped: ['delivered'],
  delivered: [],
  cancelled: [],
  refunded: [],
};

/**
 * Lookup used by OrderStatusService.setStatus(): an edge is allowed when the forward table or the
 * reversal table below lists it. A status with no row in either table cannot move.
 */
export function allowedFrom(from: OrderStatus): OrderStatus[] {
  return [...(ORDER_TRANSITIONS[from] ?? []), ...(ORDER_REVERSALS[from] ?? [])];
}

/**
 * The declared way back (finance sign-off, 2026-05): a delivered order can be refunded, and a cancelled
 * order re-opened for payment when the customer pays a stale link. setStatus() writes a history row
 * for every edge, reversals included.
 */
export const ORDER_REVERSALS: Partial<Record<OrderStatus, OrderStatus[]>> = {
  delivered: ['refunded'],
  cancelled: ['pending_payment'],
};
