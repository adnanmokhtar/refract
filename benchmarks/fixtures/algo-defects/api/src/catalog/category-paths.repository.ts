import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';

export interface CategoryPathRow {
  id: string;
  path: string;
}

/** Every category under one category, with its breadcrumb, for the merchant's "move products" dialog. */
const SUBTREE_PATHS_SQL = `
  WITH RECURSIVE t AS (
    SELECT c.id, c.parent_id, c.name::text AS path
      FROM categories c
     WHERE c.store_id = ? AND c.id = ?
    UNION ALL
    SELECT c.id, c.parent_id, t.path || ' / ' || c.name
      FROM categories c JOIN t ON c.parent_id = t.id
  )
  SELECT id, path FROM t ORDER BY path`;

@Injectable()
export class CategoryPathsRepository {
  constructor(private readonly em: EntityManager) {}

  subtreePaths(storeId: string, categoryId: string): Promise<CategoryPathRow[]> {
    return this.em.getConnection().execute<CategoryPathRow[]>(SUBTREE_PATHS_SQL, [storeId, categoryId]);
  }
}
