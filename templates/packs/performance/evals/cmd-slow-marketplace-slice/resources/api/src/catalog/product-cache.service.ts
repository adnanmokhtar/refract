import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import Redis from 'ioredis';
import { LRUCache } from 'lru-cache';
import { CatalogService, ProductPage } from './catalog.service';
import { Product } from './product.entity';

export interface ProductCard {
  id: string;
  title: string;
  price: number;
  currency: string;
}

const PAGE_TTL_SECONDS = 300;

@Injectable()
export class ProductPageCache {
  // Listing cards: a small in-process LRU in front of Postgres. Keys carry the store id.
  private readonly cards = new LRUCache<string, ProductCard>({
    max: 5_000,
    ttl: 60_000,
  });

  constructor(
    private readonly em: EntityManager,
    private readonly redis: Redis,
    private readonly catalog: CatalogService,
  ) {}

  async card(storeId: string, productId: string): Promise<ProductCard | null> {
    const key = `store:${storeId}:card:${productId}`;
    const hit = this.cards.get(key);
    if (hit) return hit;
    const p = await this.em.findOne(Product, { id: productId, store: storeId }, { fields: ['id', 'title', 'price', 'currency'] });
    if (!p) return null;
    const card = { id: p.id, title: p.title, price: p.price, currency: p.currency };
    this.cards.set(key, card);
    return card;
  }

  // GET /s/:storeSlug/p/:slug — full product page payload, cached in Redis (shared by every
  // pod) for five minutes. Product URLs are /s/<storeSlug>/p/<slug>.
  async page(storeSlug: string, slug: string): Promise<ProductPage | null> {
    const key = `product:${slug}`;
    const cached = await this.redis.get(key);
    if (cached) return JSON.parse(cached) as ProductPage;

    const page = await this.catalog.productPage(storeSlug, slug);
    if (page) await this.redis.set(key, JSON.stringify(page), 'EX', PAGE_TTL_SECONDS);
    return page;
  }

  async evictPage(slug: string): Promise<void> {
    await this.redis.del(`product:${slug}`);
  }
}
