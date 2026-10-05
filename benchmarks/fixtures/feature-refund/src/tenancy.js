// Loading records on behalf of the request's tenant.

import { HttpError } from './http.js';
import { findOrder } from './store.js';

export function requireOwnOrder(ctx, orderId) {
  const found = findOrder(ctx.store, orderId);
  if (!found) throw new HttpError(404, 'order not found');
  if (found.tenantId !== ctx.tenantId) throw new HttpError(403, 'order belongs to another tenant');
  return found.order;
}
