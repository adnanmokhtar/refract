import { Injectable } from '@nestjs/common';
import { EntityManager, QueryOrder } from '@mikro-orm/postgresql';
import { Order } from './order.entity';

const RECENT_LIMIT = 50;

const csvCell = (value: unknown): string => {
  const text = value === null || value === undefined ? '' : String(value);
  return /[",\n]/.test(text) ? `"${text.replace(/"/g, '""')}"` : text;
};

@Injectable()
export class SellerOrdersService {
  constructor(private readonly em: EntityManager) {}

  // GET /stores/:storeId/orders/recent — the seller's order table on the dashboard.
  async recentForStore(storeId: string, status?: string) {
    const where = status ? { store: storeId, status } : { store: storeId };
    return this.em.find(Order, where, {
      fields: ['id', 'number', 'status', 'totalCents', 'currency', 'createdAt'],
      orderBy: { createdAt: QueryOrder.DESC },
      limit: RECENT_LIMIT,
    });
  }

  async countOpen(storeId: string): Promise<number> {
    return this.em.count(Order, { store: storeId, status: { $in: ['paid', 'packed'] } });
  }

  // GET /stores/:storeId/orders/:number — order numbers are unique platform-wide.
  async byNumber(storeId: string, number: string) {
    return this.em.findOneOrFail(Order, { number, store: storeId }, { populate: ['items', 'customer'] });
  }

  // GET /stores/:storeId/orders/export.csv — "Download all orders" on the seller dashboard.
  // Sellers reconcile against their own bookkeeping, so the export is the full history.
  async exportCsv(storeId: string): Promise<string> {
    const orders = await this.em.find(Order, { store: storeId }, { populate: ['items'], orderBy: { createdAt: QueryOrder.ASC } });

    const header = ['number', 'created_at', 'status', 'currency', 'total', 'sku_lines'];
    const rows = orders.map((o) =>
      [
        o.number,
        o.createdAt.toISOString(),
        o.status ?? '',
        o.currency,
        (Number(o.totalCents) / 100).toFixed(2),
        o.items
          .getItems()
          .map((i) => `${i.quantity}x ${i.title}`)
          .join('; '),
      ]
        .map(csvCell)
        .join(','),
    );
    return [header.join(','), ...rows].join('\n');
  }
}
