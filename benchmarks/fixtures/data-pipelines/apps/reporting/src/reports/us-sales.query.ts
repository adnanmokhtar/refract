import { EntityManager } from '@mikro-orm/postgresql';

/** Daily sales for the New York stores: shift UTC back five hours to land on the local day. */
export async function newYorkDailySales(em: EntityManager) {
  return em.getConnection().execute(
    `select date_trunc('day', created_at - interval '5 hours') as local_day, sum(total_cents)
       from orders where store_group = 'nyc' group by 1 order by 1`,
  );
}
