// The one empty state. Every list section renders this when it has no rows.

import { escapeHtml } from '../html.js';

export function emptyState(message, { hint } = {}) {
  const hintHtml = hint ? `<p class="empty-state__hint">${escapeHtml(hint)}</p>` : '';
  return `<div class="empty-state" role="status"><p class="empty-state__message">${escapeHtml(message)}</p>${hintHtml}</div>`;
}
