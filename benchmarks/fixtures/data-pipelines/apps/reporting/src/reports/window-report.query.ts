import { EntityManager } from '@mikro-orm/postgresql';

/** Weekly report windows: [Monday 00:00, next Monday 00:00] in UTC. */
export async function ordersInWindow(em: EntityManager, tenantId: string, start: Date, nextStart: Date) {
  return em.getConnection().execute(
    `select count(*) as orders, sum(total_cents) as total_cents
       from orders
      where tenant_id = ? and created_at between ? and ?`,
    [tenantId, start, nextStart],
  );
}
