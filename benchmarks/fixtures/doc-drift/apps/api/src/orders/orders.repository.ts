import { Injectable } from '@nestjs/common';

export type OrderStatus = 'placed' | 'paid' | 'cancelled';

export interface Order {
  id: string;
  status: OrderStatus;
  totalMinor: number;
  currency: string;
}

@Injectable()
export class OrdersRepository {
  async page(_q: { cursor?: string; limit: number }): Promise<{ items: Order[]; nextCursor: string | null }> {
    return { items: [], nextCursor: null };
  }

  async insert(_input: unknown): Promise<Order> {
    return { id: 'ord_new', status: 'placed', totalMinor: 0, currency: 'EUR' };
  }

  async find(_id: string): Promise<Order | null> {
    return null;
  }

  async setStatus(id: string, status: OrderStatus): Promise<Order> {
    return { id, status, totalMinor: 0, currency: 'EUR' };
  }

  async exportCsv(): Promise<string> {
    return 'id,status,total_minor,currency\n';
  }
}
