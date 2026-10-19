import ky from 'ky';
import type { OrderDetail, OrderPage } from './types';

const api = ky.create({ prefixUrl: '/api/v2' });

export function fetchOrders(cursor?: string): Promise<OrderPage> {
  return api.get('orders', { searchParams: cursor ? { cursor } : {} }).json<OrderPage>();
}

export function fetchOrder(id: string): Promise<OrderDetail> {
  return api.get(`orders/${id}`).json<OrderDetail>();
}
