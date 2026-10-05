// Orders: lifecycle and the order endpoints.

import { HttpError, json } from './http.js';
import { addMoney, money } from './money.js';
import { recordEntry } from './ledger.js';
import { nextId, tenantOrders } from './store.js';
import { requireOwnOrder } from './tenancy.js';

export function placeOrder(store, tenantId, { customer, lines, currency = 'EUR' }) {
  const total = lines.reduce(
    (sum, line) => addMoney(sum, money(line.unitPriceMinor * line.quantity, currency)),
    money(0, currency),
  );
  const order = {
    id: nextId(store, 'ord'),
    tenantId,
    customer,
    lines,
    total,
    status: 'pending',
    shipments: [],
    placedAt: new Date().toISOString(),
  };
  tenantOrders(store, tenantId).set(order.id, order);
  store.orderTenant.set(order.id, tenantId);
  return order;
}

// Called from the payment provider's callback once the charge has succeeded.
export function payOrder(store, tenantId, orderId) {
  const order = tenantOrders(store, tenantId).get(orderId);
  if (order.status !== 'pending') throw new HttpError(409, `order ${orderId} is ${order.status}`);
  order.status = 'paid';
  recordEntry(store, tenantId, { type: 'charge', orderId, amount: order.total });
  return order;
}

export function listOrders(ctx) {
  const orders = [...tenantOrders(ctx.store, ctx.tenantId).values()];
  return json(200, { orders });
}

export function getOrder(ctx) {
  return json(200, { order: requireOwnOrder(ctx, ctx.params.id) });
}

export function cancelOrder(ctx) {
  const order = requireOwnOrder(ctx, ctx.params.id);
  if (order.status !== 'pending') {
    throw new HttpError(409, `only a pending order can be cancelled (this one is ${order.status})`);
  }
  order.status = 'cancelled';
  order.cancelledAt = new Date().toISOString();
  return json(200, { order });
}
