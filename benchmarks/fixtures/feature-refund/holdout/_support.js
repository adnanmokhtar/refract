// Holdout support — NEVER staged. score.py copies holdout/ next to src/ in a scratch copy of the
// staged tree after the run and runs each *.holdout.test.js on its own.
//
// Written against the app's conventions, not one implementation: the refund route is DISCOVERED
// in the route table (a POST whose path mentions "refund"), a refund record is found wherever a
// reasonable implementation keeps it (a ledger entry whose type mentions refund — the convention —
// or an array / Map named like "refunds" on the order or the store), and the page's empty state is
// recognised by calling the codebase's own emptyState() helper.

import { createApp } from '../src/app.js';
import { routes } from '../src/routes.js';
import { addTenant } from '../src/store.js';
import { payOrder, placeOrder } from '../src/orders.js';
import { listEntries } from '../src/ledger.js';
import { emptyState } from '../web/components/EmptyState.js';

export const TOTAL_MINOR = 1015; // €10.15 — 10.15 * 100 is 1014.9999999999999 in a float

export function setup() {
  const app = createApp();
  addTenant(app.store, 'acme');
  addTenant(app.store, 'globex');
  return app;
}

export function seed(app, tenantId, { paid = true } = {}) {
  const order = placeOrder(app.store, tenantId, {
    customer: { name: 'Holdout Customer' },
    lines: [
      { sku: 'CUP-01', name: 'Cup', quantity: 2, unitPriceMinor: 330 },
      { sku: 'TEA-02', name: 'Tea', quantity: 1, unitPriceMinor: 355 },
    ],
    currency: 'EUR',
  });
  if (paid) payOrder(app.store, tenantId, order.id);
  return order;
}

export function refundRoute() {
  const candidates = routes.filter((r) => r.method === 'POST' && /refund/i.test(r.path));
  return candidates.find((r) => /:\w+/.test(r.path)) ?? candidates[0] ?? null;
}

let n = 0;
export async function refund(app, tenantId, order, { key = `holdout-${process.pid}-${++n}` } = {}) {
  const route = refundRoute();
  if (!route) throw new Error('no POST route whose path mentions "refund" in src/routes.js');
  const path = route.path.replace(/:\w+/, encodeURIComponent(order.id));
  return app.handle({
    method: 'POST',
    path,
    headers: { 'x-tenant-id': tenantId, 'idempotency-key': key },
    body: {
      orderId: order.id,
      amount: { amountMinor: order.total.amountMinor, currency: order.total.currency },
      reason: 'customer request',
    },
  });
}

function itemsOf(value) {
  if (Array.isArray(value)) return value;
  if (value instanceof Map) return [...value.values()].flatMap((v) => (Array.isArray(v) ? v : [v]));
  return [];
}

// Every refund record for an order, by source. The count is the largest single source, so an
// implementation that writes a ledger entry AND keeps order.refunds is not counted twice.
export function refundsFor(app, orderId, order) {
  const sources = [];
  const ledger = [];
  for (const tenantId of app.store.tenants.keys()) {
    for (const e of listEntries(app.store, tenantId)) {
      if (e.orderId === orderId && /refund/i.test(String(e.type ?? e.kind ?? ''))) ledger.push(e);
    }
  }
  sources.push(ledger);
  if (order) {
    for (const [k, v] of Object.entries(order)) if (/refund/i.test(k)) sources.push(itemsOf(v));
  }
  for (const [k, v] of Object.entries(app.store)) {
    if (!/refund/i.test(k)) continue;
    sources.push(itemsOf(v).filter((r) => r && (r.orderId === orderId || r.order?.id === orderId)));
  }
  return sources.reduce((best, s) => (s.length > best.length ? s : best), []);
}

export function amountOf(record) {
  const a = record.amount;
  if (a && typeof a === 'object') return { minor: a.amountMinor, currency: a.currency };
  if (record.amountMinor !== undefined) return { minor: record.amountMinor, currency: record.currency };
  return { minor: a, currency: record.currency };
}

// The message of every empty state on the page, recognised by the shared helper's own markup.
export function emptyStateMessages(html) {
  const probe = emptyState('__HOLDOUT_PROBE__');
  const head = probe.slice(0, probe.indexOf('__HOLDOUT_PROBE__'));
  const tail = probe.slice(probe.indexOf('__HOLDOUT_PROBE__') + '__HOLDOUT_PROBE__'.length).split('<')[1];
  const messages = [];
  let at = html.indexOf(head);
  while (at !== -1) {
    const start = at + head.length;
    const end = html.indexOf('<' + (tail ?? ''), start);
    messages.push(html.slice(start, end === -1 ? start + 200 : end));
    at = html.indexOf(head, start);
  }
  return messages;
}

export function refundControls(html) {
  const buttons = [...html.matchAll(/<button\b([^>]*)>([\s\S]*?)<\/button>/gi)].filter((m) => /refund/i.test(m[1] + m[2]));
  const forms = [...html.matchAll(/<form\b[^>]*refund[^>]*>/gi)];
  return buttons.length + forms.length;
}
