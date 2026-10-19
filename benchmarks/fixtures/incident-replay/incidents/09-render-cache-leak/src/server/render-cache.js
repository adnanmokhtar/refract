// Page render cache: SSR output reused between identical requests.
const cache = new Map();

function renderCached(req, render) {
  const hit = cache.get(req.originalUrl);
  if (hit) return hit;
  const html = render(req);
  cache.set(req.originalUrl, html);
  return html;
}

module.exports = { renderCached };
