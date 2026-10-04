import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import Redis from 'ioredis';
import { Product } from '../catalog/product.entity';

// Wishlists are a Redis sorted set per user (product id → added-at); the cards are built from
// Postgres so price and stock are always current.
@Injectable()
export class WishlistService {
  constructor(
    private readonly em: EntityManager,
    private readonly redis: Redis,
  ) {}

  async add(userId: string, productId: string): Promise<void> {
    await this.redis.zadd(`wishlist:${userId}`, Date.now(), productId);
  }

  async remove(userId: string, productId: string): Promise<void> {
    await this.redis.zrem(`wishlist:${userId}`, productId);
  }

  // GET /me/wishlist — every saved product, newest first. Power users keep a few hundred.
  async list(userId: string) {
    const ids = await this.redis.zrevrange(`wishlist:${userId}`, 0, -1);

    const products = await Promise.all(
      ids.map((id) => this.em.findOne(Product, { id }, { populate: ['store'] })),
    );

    return products
      .filter((p): p is Product => p !== null && p.status === 'active')
      .map((p) => ({
        id: p.id,
        title: p.title,
        price: p.price,
        currency: p.currency,
        inStock: p.stock > 0,
        store: { slug: p.store.slug, name: p.store.name },
      }));
  }
}
