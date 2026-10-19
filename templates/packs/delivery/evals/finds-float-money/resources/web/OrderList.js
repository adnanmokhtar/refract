// The orders list page.

import { escapeHtml } from './html.js';
import { emptyState } from './components/EmptyState.js';
import { formatMoney } from '../src/money.js';

function row(order) {
  return [
    '<tr>',
    `<td><a href="/pages/orders/${escapeHtml(order.id)}">${escapeHtml(order.id)}</a></td>`,
    `<td>${escapeHtml(order.customer.name)}</td>`,
    `<td>${formatMoney(order.total)}</td>`,
    `<td><span class="status status--${escapeHtml(order.status)}">${escapeHtml(order.status)}</span></td>`,
    '</tr>',
  ].join('');
}

export function renderOrderList(orders) {
  const body =
    orders.length === 0
      ? emptyState('No orders yet', { hint: 'Orders appear here as soon as a customer checks out.' })
      : `<table class="orders"><tbody>${orders.map(row).join('')}</tbody></table>`;
  return `<main class="order-list"><h1>Orders</h1>${body}</main>`;
}
