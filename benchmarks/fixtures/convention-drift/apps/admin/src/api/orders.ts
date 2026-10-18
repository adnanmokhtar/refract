import ky from 'ky';
import type { AdminOrder } from '../stores/orders-store';

const admin = ky.create({ prefixUrl: '/api/v2/admin' });

export function fetchAdminOrders(): Promise<AdminOrder[]> {
  return admin.get('orders').json<AdminOrder[]>();
}
