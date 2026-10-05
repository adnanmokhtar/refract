export class ApiError extends Error {
  constructor(
    public status: number,
    message: string,
  ) {
    super(message);
  }
}

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const res = await fetch(`/api${path}`, {
    ...init,
    credentials: 'include',
    headers: { 'content-type': 'application/json', ...init?.headers },
    signal: init?.signal ?? AbortSignal.timeout(10_000),
  });
  if (!res.ok) throw new ApiError(res.status, res.statusText);
  return (await res.json()) as T;
}

export const api = {
  get: <T>(path: string, init?: RequestInit) => request<T>(path, init),
  post: <T>(path: string, body: unknown) => request<T>(path, { method: 'POST', body: JSON.stringify(body) }),
  patch: <T>(path: string, body: unknown) => request<T>(path, { method: 'PATCH', body: JSON.stringify(body) }),
  del: <T>(path: string) => request<T>(path, { method: 'DELETE' }),
};

export type Product = { id: string; slug: string; name: string; price: number; image: string; saleEndsAt?: string };
export type BasketLine = { id: string; productId: string; name: string; qty: number; price: number };
export type Order = { id: string; number: string; placedAt: string; total: number; status: 'placed' | 'picking' | 'out-for-delivery' | 'delivered' };
export type Address = { id: string; line1: string; city: string; phone?: string };
export type Profile = { id: string; name: string; email: string };
