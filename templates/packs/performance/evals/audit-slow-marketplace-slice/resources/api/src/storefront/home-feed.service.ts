import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import Redis from 'ioredis';
import { RecommendationsClient } from './recommendations.client';

export interface HomeFeed {
  builtAt: string;
  featured: { id: string; slug: string; title: string; price: number; currency: string }[];
  categories: { slug: string; products: number }[];
}

export interface CategoryNode {
  slug: string;
  name: string;
  children: CategoryNode[];
}

const FEED_KEY = 'home:feed:v3';
const FEED_TTL_SECONDS = 60;

@Injectable()
export class HomeFeedService {
  private readonly inflight = new Map<string, Promise<CategoryNode[]>>();

  constructor(
    private readonly em: EntityManager,
    private readonly redis: Redis,
    private readonly recs: RecommendationsClient,
  ) {}

  // GET /home — the storefront landing page; the busiest endpoint we have (~1 400 rps at the
  // evening peak). The feed is the same for every visitor.
  async feed(): Promise<HomeFeed> {
    const cached = await this.redis.get(FEED_KEY);
    if (cached) return JSON.parse(cached) as HomeFeed;

    const feed = await this.buildFeed();
    await this.redis.set(FEED_KEY, JSON.stringify(feed), 'EX', FEED_TTL_SECONDS);
    return feed;
  }

  // GET /categories — the navigation tree, shown in the header of every page.
  //
  // Rebuilt from the database at most once per pod at a time: concurrent callers that miss
  // share the same rebuild instead of each running it.
  async categoryTree(): Promise<CategoryNode[]> {
    const key = 'categories:tree';
    const cached = await this.redis.get(key);
    if (cached) return JSON.parse(cached) as CategoryNode[];

    const pending = this.inflight.get(key);
    if (pending) return pending;

    const rebuild = this.loadCategoryTree()
      .then(async (tree) => {
        await this.redis.set(key, JSON.stringify(tree), 'EX', 600);
        return tree;
      })
      .finally(() => this.inflight.delete(key));
    this.inflight.set(key, rebuild);
    return rebuild;
  }

  // Featured products come from the recommendations service's ranking job (~1.2 s per call,
  // and the service is sized for a few calls a minute); category counts from a view the
  // worker refreshes.
  private async buildFeed(): Promise<HomeFeed> {
    const [featured, categories] = await Promise.all([
      this.recs.featured({ limit: 24 }),
      this.em.execute<{ slug: string; products: string }[]>('select slug, products from category_counts order by products desc limit 40'),
    ]);
    return {
      builtAt: new Date().toISOString(),
      featured: featured.map((p) => ({ id: p.productId, slug: p.slug, title: p.title, price: p.priceCents / 100, currency: p.currency })),
      categories: categories.map((c) => ({ slug: c.slug, products: Number(c.products) })),
    };
  }

  private async loadCategoryTree(): Promise<CategoryNode[]> {
    const rows = await this.em.execute<{ slug: string; name: string; parent: string | null }[]>('select slug, name, parent from category order by name');
    const bySlug = new Map(rows.map((r) => [r.slug, { slug: r.slug, name: r.name, children: [] as CategoryNode[] }]));
    const roots: CategoryNode[] = [];
    for (const r of rows) (r.parent ? bySlug.get(r.parent)?.children : roots)?.push(bySlug.get(r.slug)!);
    return roots;
  }
}
