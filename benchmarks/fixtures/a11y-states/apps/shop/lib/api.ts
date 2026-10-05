export class ApiError extends Error {
  constructor(
    public status: number,
    public code: string,
    message: string,
  ) {
    super(message);
  }
}

const BASE = process.env.NEXT_PUBLIC_API_URL ?? '/api';

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const res = await fetch(`${BASE}${path}`, {
    ...init,
    credentials: 'include',
    headers: { 'content-type': 'application/json', ...init?.headers },
    signal: init?.signal ?? AbortSignal.timeout(10_000),
  });
  if (!res.ok) {
    const body = await res.json().catch(() => ({}));
    throw new ApiError(res.status, body.code ?? 'unknown', body.message ?? res.statusText);
  }
  return res.json() as Promise<T>;
}

export const api = {
  get: <T>(path: string, init?: RequestInit) => request<T>(path, init),
  post: <T>(path: string, body: unknown) => request<T>(path, { method: 'POST', body: JSON.stringify(body) }),
  put: <T>(path: string, body: unknown) => request<T>(path, { method: 'PUT', body: JSON.stringify(body) }),
  del: <T>(path: string) => request<T>(path, { method: 'DELETE' }),
};

export type Product = { id: string; slug: string; name: string; price: number; image: string; onSale: boolean };
export type Order = { id: string; number: string; placedAt: string; total: number; status: 'paid' | 'shipped' | 'delivered' };
export type CartLine = { id: string; productId: string; name: string; qty: number; price: number; image: string };
export type Loyalty = { points: number; tier: 'leaf' | 'branch' | 'tree' };
export type StoreCredit = { balance: number; currency: string };
export type SpendPoint = { month: string; spend: number; change: number };
export type PointsPoint = { week: string; points: number | null };

// Store credit and gift cards are only readable once the customer has verified their email;
// the API answers 403 { code: 'email_unverified' } until then.
export const accountApi = {
  recentlyViewed: () => api.get<Product[]>('/me/recently-viewed'),
  wishlist: () => api.get<{ items: Product[] }>('/me/wishlist'),
  orders: () => api.get<Order[]>('/me/orders'),
  loyalty: () => api.get<Loyalty>('/me/loyalty'),
  storeCredit: () => api.get<StoreCredit>('/me/store-credit'),
  giftCards: () => api.get<{ code: string; balance: number }[]>('/me/gift-cards'),
  spend: () => api.get<SpendPoint[]>('/me/insights/spend'),
  points: () => api.get<PointsPoint[]>('/me/insights/points'),
};
