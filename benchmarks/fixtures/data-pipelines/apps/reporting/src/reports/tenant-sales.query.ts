import { EntityManager } from '@mikro-orm/postgresql';

/** Tenant dashboard: sales per local day, in the tenant's own zone (tenants span UTC-5 to UTC+4). */
export async function tenantDailySales(em: EntityManager, tenantId: string, timeZone: string, from: string, to: string) {
  return em.getConnection().execute(
    `select day, sum(total_cents) as total_cents
       from order_day_facts
      where tenant_id = ? and day >= ?::date and day < ?::date
      group by day order by day`,
    [tenantId, from, to],
  );
}
