// The in-memory store. Orders live under their tenant; `orderTenant` indexes an order id to its
// tenant so the edge can tell "another tenant's order" (403) from "no such order" (404).

import { HttpError } from './http.js';

export function createStore() {
  return {
    tenants: new Map(), // tenantId -> { id, name, orders: Map<orderId, order> }
    orderTenant: new Map(), // orderId -> tenantId
    ledger: new Map(), // tenantId -> entry[]
    idempotency: new Map(), // `${tenantId} ${route} ${key}` -> first response
    seq: 0,
  };
}

export function addTenant(store, tenantId, { name = tenantId } = {}) {
  store.tenants.set(tenantId, { id: tenantId, name, orders: new Map() });
}

export function tenantOrders(store, tenantId) {
  const tenant = store.tenants.get(tenantId);
  if (!tenant) throw new HttpError(401, 'unknown tenant');
  return tenant.orders;
}

export function nextId(store, prefix) {
  store.seq += 1;
  return `${prefix}_${String(store.seq).padStart(4, '0')}`;
}

// Tenant-blind lookup. Only for the payment provider's callback, which carries no tenant —
// request handlers go through requireOwnOrder() in src/tenancy.js.
export function findOrder(store, orderId) {
  const tenantId = store.orderTenant.get(orderId);
  if (!tenantId) return null;
  return { tenantId, order: tenantOrders(store, tenantId).get(orderId) };
}
