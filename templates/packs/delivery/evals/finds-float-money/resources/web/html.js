// Every interpolated value in a page goes through escapeHtml().

const ENTITIES = { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' };

export function escapeHtml(value) {
  return String(value).replace(/[&<>"']/g, (ch) => ENTITIES[ch]);
}
