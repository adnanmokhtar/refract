import DataLoader from 'dataloader';
import { EntityManager } from '@mikro-orm/postgresql';
import { Brand } from './brand.entity';

// Built per GraphQL request (see the context factory in app.module.ts) so cached rows never
// outlive the request that loaded them.
export const createProductLoaders = (em: EntityManager) => ({
  brandById: new DataLoader<string, Brand | null>(async (ids) => {
    const brands = await em.find(Brand, { id: { $in: [...ids] } });
    const byId = new Map(brands.map((b) => [b.id, b]));
    return ids.map((id) => byId.get(id) ?? null);
  }),
});

export type ProductLoaders = ReturnType<typeof createProductLoaders>;
