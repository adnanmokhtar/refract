// Server-rendered pages.

import { html } from './http.js';
import { tenantOrders } from './store.js';
import { requireOwnOrder } from './tenancy.js';
import { renderOrderDetails } from '../web/OrderDetails.js';
import { renderOrderList } from '../web/OrderList.js';

export function ordersPage(ctx) {
  return html(renderOrderList([...tenantOrders(ctx.store, ctx.tenantId).values()]));
}

export function orderPage(ctx) {
  return html(renderOrderDetails(requireOwnOrder(ctx, ctx.params.id)));
}
