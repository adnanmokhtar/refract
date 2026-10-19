import 'server-only';
import type { Product } from '../api';

const API = process.env.CATALOG_API_URL ?? 'http://catalog.internal';
const TOKEN = process.env.CATALOG_API_TOKEN;

export async function getProduct(slug: string): Promise<Product | null> {
  const res = await fetch(`${API}/products/${encodeURIComponent(slug)}`, {
    headers: { authorization: `Bearer ${TOKEN}` },
    next: { revalidate: 300, tags: [`product:${slug}`] },
  });
  if (res.status === 404) return null;
  if (!res.ok) throw new Error(`catalog answered ${res.status}`);
  return res.json();
}

export async function getCategory(path: string[]): Promise<{ title: string; products: Product[] } | null> {
  const res = await fetch(`${API}/categories/${path.map(encodeURIComponent).join('/')}`, { next: { revalidate: 300 } });
  if (res.status === 404) return null;
  if (!res.ok) throw new Error(`catalog answered ${res.status}`);
  return res.json();
}
