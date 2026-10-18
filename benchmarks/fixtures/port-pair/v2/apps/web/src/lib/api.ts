const BASE = '/api';

// Cookie-authenticated writes echo Laravel's XSRF-TOKEN cookie, as the V1 portal's axios did.
const xsrf = () => decodeURIComponent(document.cookie.match(/(?:^|; )XSRF-TOKEN=([^;]*)/)?.[1] ?? '');

async function request<T>(method: string, path: string, body?: unknown): Promise<T> {
  const res = await fetch(`${BASE}${path}`, {
    method,
    credentials: 'include',
    headers: { 'content-type': 'application/json', accept: 'application/json', 'x-xsrf-token': xsrf() },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  if (!res.ok) {
    throw Object.assign(new Error(`HTTP ${res.status}`), { status: res.status, body: await res.json().catch(() => null) });
  }
  return res.json() as Promise<T>;
}

export const api = {
  get: <T>(path: string) => request<T>('GET', path),
  post: <T>(path: string, body?: unknown) => request<T>('POST', path, body),
  patch: <T>(path: string, body?: unknown) => request<T>('PATCH', path, body),
};
