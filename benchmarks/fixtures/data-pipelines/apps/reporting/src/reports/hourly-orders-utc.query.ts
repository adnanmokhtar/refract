import { EntityManager } from '@mikro-orm/postgresql';

/** The same chart for the support console: attach UTC to the naive column first, then convert. */
export async function eventsPerLocalHour(em: EntityManager, tenantId: string, zone: string) {
  return em.getConnection().execute(
    `select date_trunc('hour', (created_at at time zone 'UTC') at time zone ?) as local_hour, count(*) as events
       from events where tenant_id = ? group by 1 order by 1`,
    [zone, tenantId],
  );
}
