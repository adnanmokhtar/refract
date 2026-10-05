// Refunds: give a paid order's money back. Reference solution (benchmarks only — never staged).

import { HttpError, json } from './http.js';
import { listEntries, recordEntry } from './ledger.js';
import { findOrder } from './store.js';

export function refundOrder(ctx) {
  const found = findOrder(ctx.store, ctx.params.id);
  if (!found) throw new HttpError(404, 'order not found');
  const order = found.order;
  if (order.status !== 'paid') {
    throw new HttpError(409, `only a paid order can be refunded (this one is ${order.status})`);
  }
  const refund = recordEntry(ctx.store, ctx.tenantId, {
    type: 'refund',
    orderId: order.id,
    amount: order.total,
    reason: typeof ctx.body.reason === 'string' ? ctx.body.reason : null,
  });
  order.status = 'refunded';
  return json(201, { refund, order });
}

export function refundsForOrder(store, tenantId, orderId) {
  return listEntries(store, tenantId, { type: 'refund', orderId });
}
