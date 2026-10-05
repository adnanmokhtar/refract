// The route table. One row per endpoint or page; src/app.js matches them in order.

import { cancelOrder, getOrder, listOrders } from './orders.js';
import { orderPage, ordersPage } from './pages.js';
import { refundOrder } from './refunds.js';
import { withIdempotency } from './idempotency.js';

export const routes = [
  { method: 'GET', path: '/orders', handler: listOrders },
  { method: 'GET', path: '/orders/:id', handler: getOrder },
  { method: 'POST', path: '/orders/:id/cancel', handler: withIdempotency(cancelOrder) },
  { method: 'POST', path: '/orders/:id/refund', handler: refundOrder },
  { method: 'GET', path: '/pages/orders', handler: ordersPage },
  { method: 'GET', path: '/pages/orders/:id', handler: orderPage },
];
