import { Injectable } from '@nestjs/common';

type OrderRow = { id: string; status: string; isArchived: boolean; deletedAt: string | null };

@Injectable()
export class OrdersRepository {
  private readonly rows = new Map<string, OrderRow>();
  private readonly statusCache = new Map<string, string>();

  async warmStatusCache() {
    for (const row of this.rows.values()) this.statusCache.set(row.id, row.status);
  }

  async page(cursor: string | undefined, limit: number) {
    const all = [...this.rows.values()].filter((r) => !r.deletedAt);
    const start = cursor ? all.findIndex((r) => r.id === cursor) + 1 : 0;
    const items = all.slice(start, start + limit);
    return { items, nextCursor: items.length === limit ? items[items.length - 1]!.id : null };
  }

  async byId(id: string) {
    return this.rows.get(id) ?? null;
  }

  async setStatus(id: string, status: string) {
    const row = this.rows.get(id);
    if (row) row.status = status;
    return row ?? null;
  }

  async setArchived(id: string) {
    const row = this.rows.get(id);
    if (row) row.isArchived = true;
  }

  async setDeleted(id: string) {
    const row = this.rows.get(id);
    if (row) row.deletedAt = new Date().toISOString();
  }

  emit(event: string, payload: object) {
    process.emitWarning(JSON.stringify({ event, payload }), 'OrderEvent');
  }
}
