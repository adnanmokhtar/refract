import { EntityManager } from '@mikro-orm/postgresql';

/** Page views per local day for the content team. */
export async function pageViewsPerDay(em: EntityManager, tenantId: string, zone: string) {
  return em.getConnection().execute(
    `select to_char(viewed_at at time zone ?, 'YYYY-MM-DD') as day, count(*) as views
       from page_views where tenant_id = ? group by 1 order by 1`,
    [zone, tenantId],
  );
}
