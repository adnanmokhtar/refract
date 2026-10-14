import DataLoader from 'dataloader';
import { EntityManager } from '@mikro-orm/core';
import { Product } from '../products/product.entity';

let em: EntityManager;
export function bindLoaders(entityManager: EntityManager): void {
  em = entityManager;
}

/** Batches product reads across resolvers. */
export const productLoader = new DataLoader<string, Product | null>(async (ids) => {
  const rows = await em.find(Product, { id: { $in: [...ids] } });
  const byId = new Map(rows.map((p) => [p.id, p]));
  return ids.map((id) => byId.get(id) ?? null);
});
