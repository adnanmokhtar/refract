import 'server-only';
import { cookies } from 'next/headers';
import type { Address, Order } from '../api';

const API = process.env.ACCOUNT_API_URL ?? 'http://account.internal';

async function get<T>(path: string): Promise<T> {
  const jar = await cookies();
  const res = await fetch(`${API}${path}`, { headers: { cookie: jar.toString() }, cache: 'no-store' });
  if (!res.ok) throw new Error(`${path} answered ${res.status}`);
  return res.json();
}

export const getOrders = () => get<Order[]>('/me/orders');
export const getAddresses = () => get<Address[]>('/me/addresses');
export const getSession = () => get<{ customerId: string; name: string } | null>('/me/session');
