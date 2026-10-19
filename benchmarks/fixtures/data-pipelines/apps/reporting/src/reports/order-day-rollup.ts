import { EntityManager } from '@mikro-orm/postgresql';

/**
 * Whole-day replacement: every dirty day is deleted and recomputed from `orders` in one
 * transaction, so a doubled pass is harmless. Quarter-hour facts sit beside the UTC days so a
 * tenant-zone day is re-bucketed from the quarters, never from the UTC days.
 */
const UTC_DAY = (column: string): string => `(${column} at time zone 'UTC')::date`;
const QUARTER = (column: string): string => `date_bin('15 minutes', ${column}, timestamptz '2001-01-01 00:00:00+00')`;

export async function rebuildDirtyDays(em: EntityManager, tenantId: string, days: string[]): Promise<void> {
  await em.transactional(async (tx) => {
    const conn = tx.getConnection();
    await conn.execute(`delete from order_day_facts where tenant_id = ? and day = any(?::date[])`, [tenantId, days]);
    await conn.execute(
      `insert into order_day_facts (tenant_id, day, store_id, status, orders, total_cents)
       select tenant_id, ${UTC_DAY('created_at')}, store_id, status, count(*), sum(total_cents)
         from orders where tenant_id = ? and ${UTC_DAY('created_at')} = any(?::date[])
        group by 1, 2, 3, 4`,
      [tenantId, days],
    );
    await conn.execute(
      `delete from order_quarter_facts where tenant_id = ? and ${UTC_DAY('bucket')} = any(?::date[])`,
      [tenantId, days],
    );
    await conn.execute(
      `insert into order_quarter_facts (tenant_id, bucket, orders, total_cents)
       select tenant_id, ${QUARTER('created_at')}, count(*), sum(total_cents)
         from orders where tenant_id = ? and ${UTC_DAY('created_at')} = any(?::date[])
        group by 1, 2`,
      [tenantId, days],
    );
    await conn.execute(`delete from order_rollup_dirty_days where tenant_id = ? and day = any(?::date[])`, [tenantId, days]);
  });
}
