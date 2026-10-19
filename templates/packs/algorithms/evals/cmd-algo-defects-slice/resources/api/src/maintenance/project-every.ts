import { EntityManager } from '@mikro-orm/postgresql';
import { Product } from '../catalog/product.entity';

const PAGE = 1000;

/** Runs `project` over every product once, in id order (search re-index, backfills). */
export async function projectEveryProduct(em: EntityManager, project: (rows: Product[]) => Promise<void>): Promise<number> {
  let lastId = '00000000-0000-0000-0000-000000000000';
  let seen = 0;
  for (;;) {
    const rows = await em.fork().find(Product, { id: { $gt: lastId } }, { limit: PAGE, orderBy: { id: 'asc' } });
    if (rows.length > 0) {
      await project(rows);
      seen += rows.length;
      lastId = rows[rows.length - 1].id;
    }
    if (rows.length < PAGE) break;
  }
  return seen;
}
