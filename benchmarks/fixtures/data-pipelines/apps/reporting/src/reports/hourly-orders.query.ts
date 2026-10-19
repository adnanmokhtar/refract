import { EntityManager } from '@mikro-orm/postgresql';

/** Orders per local hour for the activity chart; events.created_at is timestamp(3) holding UTC. */
export async function eventsPerLocalDay(em: EntityManager, tenantId: string, zone: string) {
  return em.getConnection().execute(
    `select date_trunc('day', created_at at time zone ?) as local_day, count(*) as events
       from events where tenant_id = ? group by 1 order by 1`,
    [zone, tenantId],
  );
}
