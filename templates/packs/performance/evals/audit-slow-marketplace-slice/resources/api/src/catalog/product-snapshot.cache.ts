import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import { Product } from './product.entity';

export interface ProductSnapshot {
  id: string;
  storeId: string;
  title: string;
  price: number;
  currency: string;
  stock: number;
  cachedAt: number;
}

const FRESH_FOR_MS = 60_000;

// Product cards for the cart drawer and the checkout summary. Cart pages re-read the same
// few products many times a minute; a hit here saves a query.
const snapshots = new Map<string, ProductSnapshot>();

@Injectable()
export class ProductSnapshotCache {
  constructor(private readonly em: EntityManager) {}

  async get(productId: string): Promise<ProductSnapshot | null> {
    const hit = snapshots.get(productId);
    if (hit && Date.now() - hit.cachedAt < FRESH_FOR_MS) return hit;

    const product = await this.em.findOne(Product, { id: productId }, { fields: ['id', 'store', 'title', 'price', 'currency', 'stock'] });
    if (!product) return null;

    const snapshot: ProductSnapshot = {
      id: product.id,
      storeId: product.store.id,
      title: product.title,
      price: product.price,
      currency: product.currency,
      stock: product.stock,
      cachedAt: Date.now(),
    };
    snapshots.set(productId, snapshot);
    return snapshot;
  }

  // Called by the product update handler.
  invalidate(productId: string): void {
    snapshots.delete(productId);
  }
}
