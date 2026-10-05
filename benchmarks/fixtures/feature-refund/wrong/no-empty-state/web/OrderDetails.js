// The order details page.

import { escapeHtml } from './html.js';
import { emptyState } from './components/EmptyState.js';
import { formatMoney } from '../src/money.js';

function cancelButton(order) {
  return [
    `<form method="post" action="/orders/${escapeHtml(order.id)}/cancel" class="order-action">`,
    '<button type="submit" class="button button--secondary">Cancel order</button>',
    '</form>',
  ].join('');
}

function refundButton(order) {
  return [
    `<form method="post" action="/orders/${escapeHtml(order.id)}/refund" class="order-action">`,
    '<button type="submit" class="button button--danger">Refund order</button>',
    '</form>',
  ].join('');
}

function renderLines(order) {
  const items = order.lines
    .map(
      (line) =>
        `<li>${escapeHtml(line.quantity)} × ${escapeHtml(line.name)} — ${formatMoney({
          amountMinor: line.unitPriceMinor * line.quantity,
          currency: order.total.currency,
        })}</li>`,
    )
    .join('');
  return `<section class="order-section"><h2>Items</h2><ul class="lines">${items}</ul></section>`;
}

function renderShipments(order) {
  const body =
    order.shipments.length === 0
      ? emptyState('No shipments yet')
      : `<ul class="shipments">${order.shipments
          .map((s) => `<li>${escapeHtml(s.carrier)} ${escapeHtml(s.tracking)}</li>`)
          .join('')}</ul>`;
  return `<section class="order-section"><h2>Shipments</h2>${body}</section>`;
}

function renderRefunds(refunds) {
  const body =
    refunds.length === 0
      ? '<p class="muted">No refunds yet</p>'
      : `<ul class="refunds">${refunds
          .map((r) => `<li>${formatMoney(r.amount)} — ${escapeHtml(r.reason ?? 'no reason given')}</li>`)
          .join('')}</ul>`;
  return `<section class="order-section"><h2>Refunds</h2>${body}</section>`;
}

export function renderOrderDetails(order, { refunds = [] } = {}) {
  return [
    `<article class="order-details" data-order-id="${escapeHtml(order.id)}">`,
    '<header class="order-header">',
    `<h1>Order ${escapeHtml(order.id)}</h1>`,
    `<p class="order-total">Ordr total: ${formatMoney(order.total)}</p>`,
    `<span class="status status--${escapeHtml(order.status)}">${escapeHtml(order.status)}</span>`,
    order.status === 'pending' ? cancelButton(order) : '',
    order.status === 'paid' ? refundButton(order) : '',
    '</header>',
    renderLines(order),
    renderShipments(order),
    renderRefunds(refunds),
    '</article>',
  ].join('\n');
}
