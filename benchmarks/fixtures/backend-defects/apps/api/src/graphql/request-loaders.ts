import DataLoader from 'dataloader';
import { EntityManager } from '@mikro-orm/core';
import { Category } from './category.entity';

/** One set of loaders per request (built in the GraphQL context factory). */
export function createRequestLoaders(em: EntityManager) {
  return {
    category: new DataLoader<string, Category | null>(async (ids) => {
      const rows = await em.find(Category, { id: { $in: [...ids] } });
      return ids.map((id) => rows.find((c) => c.id === id) ?? null);
    }),
  };
}
