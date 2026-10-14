import { EntityManager, FilterQuery, QueryOrder } from '@mikro-orm/core';

export const MAX_PAGE_SIZE = 100;

export interface PageRequest<S extends string> {
  page: number;
  pageSize: number;
  sort: S;
  dir: 'asc' | 'desc';
}

export interface PageResult<T> {
  items: T[];
  page: number;
  pageSize: number;
  total: number;
}

/**
 * The pagination kernel. Every client-visible list calls this: page size clamped, sort field
 * allow-listed by the caller's type, `id` appended as the unique tiebreak, `total` counted under
 * the same `where`.
 */
export async function paginate<T extends object, S extends string>(
  em: EntityManager,
  entity: new () => T,
  where: FilterQuery<T>,
  req: PageRequest<S>,
  allowedSorts: readonly S[],
): Promise<PageResult<T>> {
  const pageSize = Math.min(Math.max(req.pageSize, 1), MAX_PAGE_SIZE);
  const sort = allowedSorts.includes(req.sort) ? req.sort : allowedSorts[0];
  const dir = req.dir === 'asc' ? QueryOrder.ASC : QueryOrder.DESC;
  const [items, total] = await em.findAndCount(entity, where, {
    orderBy: [{ [sort]: dir }, { id: QueryOrder.ASC }] as never,
    limit: pageSize,
    offset: (Math.max(req.page, 1) - 1) * pageSize,
  });
  return { items, page: req.page, pageSize, total };
}
