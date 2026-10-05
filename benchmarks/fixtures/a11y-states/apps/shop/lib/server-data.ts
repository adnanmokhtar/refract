import 'server-only';
import { cookies } from 'next/headers';
import type { Loyalty, Order, Product } from './api';

const API = process.env.API_INTERNAL_URL ?? 'http://api.internal:8080';

async function serverGet<T>(path: string): Promise<T> {
  const jar = await cookies();
  const res = await fetch(`${API}${path}`, {
    headers: { cookie: jar.toString() },
    cache: 'no-store',
    signal: AbortSignal.timeout(5_000),
  });
  if (!res.ok) throw new Error(`${path} answered ${res.status}`);
  return res.json() as Promise<T>;
}

export const getRecentOrders = () => serverGet<Order[]>('/me/orders?limit=3');
export const getLoyalty = () => serverGet<Loyalty>('/me/loyalty');
export const getRecommendations = () => serverGet<Product[]>('/me/recommendations?limit=4');
export async function getProduct(slug: string) {
  const jar = await cookies();
  const res = await fetch(`${API}/products/${encodeURIComponent(slug)}`, {
    headers: { cookie: jar.toString() },
    next: { revalidate: 300 },
    signal: AbortSignal.timeout(5_000),
  });
  if (res.status === 404) return null;
  if (!res.ok) throw new Error(`/products/${slug} answered ${res.status}`);
  return (await res.json()) as Product & { description: string; gallery: string[] };
}
export const getFeatured = () => serverGet<Product[]>('/products/featured');
