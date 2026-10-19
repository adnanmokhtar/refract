import type { Knex } from 'knex';
import { collectPages } from './export-size';

const PAGE = 1000;

/** Orders export: keyset on (created_at desc, id desc), compared in SQL so no row sharing a timestamp is skipped. */
export class OrdersExportRunner {
  constructor(private readonly knex: Knex) {}

  async run(tenantId: string) {
    let last: { createdAt: string; id: string } | null = null;
    return collectPages('orders', async () => {
      const q = this.knex('orders').where({ tenant_id: tenantId }).orderBy([{ column: 'created_at', order: 'desc' }, { column: 'id', order: 'desc' }]).limit(PAGE);
      if (last) q.whereRaw('(created_at, id) < (?::timestamptz, ?::uuid)', [last.createdAt, last.id]);
      const items = await q;
      const tail = items[items.length - 1];
      if (tail) last = { createdAt: tail.created_at, id: tail.id };
      return { items, last: items.length < PAGE };
    });
  }
}
