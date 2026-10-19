import { createApp } from '../src/app.js';
import { addTenant } from '../src/store.js';
import { payOrder, placeOrder } from '../src/orders.js';

export function setup() {
  const app = createApp();
  addTenant(app.store, 'acme');
  addTenant(app.store, 'globex');
  return app;
}

export function seedOrder(app, tenantId, { paid = false } = {}) {
  const order = placeOrder(app.store, tenantId, {
    customer: { name: 'Ada Example' },
    lines: [{ sku: 'MUG-01', name: 'Mug', quantity: 2, unitPriceMinor: 1250 }],
  });
  if (paid) payOrder(app.store, tenantId, order.id);
  return order;
}

let keys = 0;
export function post(app, tenantId, path, { key = `test-${++keys}`, body = {} } = {}) {
  return app.handle({ method: 'POST', path, headers: { 'x-tenant-id': tenantId, 'idempotency-key': key }, body });
}

export function get(app, tenantId, path) {
  return app.handle({ method: 'GET', path, headers: { 'x-tenant-id': tenantId } });
}
