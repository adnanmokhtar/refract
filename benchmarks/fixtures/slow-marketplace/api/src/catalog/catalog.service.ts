import { Injectable } from '@nestjs/common';
import { EntityManager, QueryOrder } from '@mikro-orm/postgresql';
import { Product } from './product.entity';

const PAGE_SIZE = 48;

export interface ProductCardRow {
  id: string;
  slug: string;
  title: string;
  price: number;
  currency: string;
}

export interface ProductPage extends ProductCardRow {
  descriptionHtml: string;
  stock: number;
  store: { slug: string; name: string };
}

@Injectable()
export class CatalogService {
  constructor(private readonly em: EntityManager) {}

  // GET /catalog/:category?page=N — public category pages. Crawlers and the "next page"
  // links walk them; the storefront renders "page N" in the URL so links stay shareable.
  async browse(category: string, page: number): Promise<{ items: ProductCardRow[]; page: number; hasNext: boolean }> {
    const rows = await this.em.find(
      Product,
      { category, status: 'active' },
      {
        fields: ['id', 'slug', 'title', 'price', 'currency'],
        orderBy: { createdAt: QueryOrder.DESC },
        limit: PAGE_SIZE + 1,
        offset: (page - 1) * PAGE_SIZE,
      },
    );
    return { items: rows.slice(0, PAGE_SIZE), page, hasNext: rows.length > PAGE_SIZE };
  }

  // GET /search?q= — the storefront search box; the typeahead calls it from the second
  // character on. Optional store filter on a store's own page.
  async search(q: string, storeId?: string): Promise<ProductCardRow[]> {
    const qb = this.em
      .createQueryBuilder(Product, 'p')
      .select(['p.id', 'p.slug', 'p.title', 'p.price', 'p.currency'])
      .where({ status: 'active' })
      .andWhere(`p.title ilike '%' || ? || '%'`, [q.trim()])
      .orderBy({ createdAt: QueryOrder.DESC })
      .limit(20);
    if (storeId) qb.andWhere({ store: storeId });
    return qb.getResultList();
  }

  // GET /s/:storeSlug/p/:slug — the product page.
  async productPage(storeSlug: string, slug: string): Promise<ProductPage | null> {
    const product = await this.em.findOne(
      Product,
      { slug, status: 'active', store: { slug: storeSlug, status: 'published' } },
      { populate: ['store', 'descriptionHtml'] },
    );
    if (!product) return null;
    return {
      id: product.id,
      slug: product.slug,
      title: product.title,
      price: product.price,
      currency: product.currency,
      descriptionHtml: product.descriptionHtml,
      stock: product.stock,
      store: { slug: product.store.slug, name: product.store.name },
    };
  }
}
