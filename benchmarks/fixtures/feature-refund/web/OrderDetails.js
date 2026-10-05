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

export function renderOrderDetails(order) {
  return [
    `<article class="order-details" data-order-id="${escapeHtml(order.id)}">`,
    '<header class="order-header">',
    `<h1>Order ${escapeHtml(order.id)}</h1>`,
    `<p class="order-total">Ordr total: ${formatMoney(order.total)}</p>`,
    `<span class="status status--${escapeHtml(order.status)}">${escapeHtml(order.status)}</span>`,
    order.status === 'pending' ? cancelButton(order) : '',
    '</header>',
    renderLines(order),
    renderShipments(order),
    '</article>',
  ].join('\n');
}
