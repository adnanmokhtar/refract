import { EntityManager } from '@mikro-orm/postgresql';

/** Daily sales for the Berlin store group. */
export async function berlinDailySales(em: EntityManager) {
  return em.getConnection().execute(
    `select (created_at at time zone '+01')::date as local_day, sum(total_cents)
       from orders where store_group = 'berlin' group by 1 order by 1`,
  );
}
