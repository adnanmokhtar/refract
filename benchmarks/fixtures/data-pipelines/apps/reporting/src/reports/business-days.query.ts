import { EntityManager } from '@mikro-orm/postgresql';

/** Counts open business days in a closed date range; `day` is a date column, both ends inclusive by design. */
export async function openDays(em: EntityManager, storeId: string, firstDay: string, lastDay: string) {
  return em.getConnection().execute(
    `select count(*) from store_calendar where store_id = ? and is_open and day between ?::date and ?::date`,
    [storeId, firstDay, lastDay],
  );
}
