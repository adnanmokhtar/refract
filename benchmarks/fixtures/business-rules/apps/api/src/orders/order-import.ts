import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import { Order } from './order.entity';

interface ImportedRow {
  external_id: string;
  total: string;
  currency: string;
}

/** Imports historical orders from a marketplace CSV export (major units as text). */
@Injectable()
export class OrderImport {
  constructor(private readonly em: EntityManager) {}

  async importRow(storeId: string, row: ImportedRow): Promise<Order> {
    const totalMinor = Math.round(parseFloat(row.total) * 100);
    return this.em.create(Order, {
      id: row.external_id,
      store: storeId,
      customerId: 'imported',
      currency: row.currency,
      subtotalMinor: totalMinor,
      totalMinor,
      status: 'delivered',
    });
  }
}
