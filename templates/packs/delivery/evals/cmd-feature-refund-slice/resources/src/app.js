// The edge: tenant resolution, routing, error mapping. Transport-agnostic — server.js (not in this
// repo) adapts node:http requests to handle({ method, path, headers, body }).

import { HttpError, json } from './http.js';
import { routes } from './routes.js';
import { createStore } from './store.js';

export function matchPath(pattern, path) {
  const want = pattern.split('/');
  const got = path.split('?')[0].split('/');
  if (want.length !== got.length) return null;
  const params = {};
  for (let i = 0; i < want.length; i += 1) {
    if (want[i].startsWith(':')) params[want[i].slice(1)] = decodeURIComponent(got[i]);
    else if (want[i] !== got[i]) return null;
  }
  return params;
}

export function createApp({ store = createStore() } = {}) {
  async function handle({ method, path, headers = {}, body = {} }) {
    const lower = Object.fromEntries(Object.entries(headers).map(([k, v]) => [k.toLowerCase(), v]));
    const tenantId = lower['x-tenant-id'];
    if (!tenantId || !store.tenants.has(tenantId)) return json(401, { error: 'unknown tenant' });

    for (const route of routes) {
      if (route.method !== method) continue;
      const params = matchPath(route.path, path);
      if (!params) continue;
      const ctx = { store, tenantId, params, headers: lower, body, route: `${route.method} ${route.path}` };
      try {
        return await route.handler(ctx);
      } catch (err) {
        if (err instanceof HttpError) return json(err.status, { error: err.message });
        throw err;
      }
    }
    return json(404, { error: 'no such route' });
  }
  return { store, handle };
}
