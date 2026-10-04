import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

const PAGE_SIZE = 24;

export interface ProductRow {
  id: string;
  title: string;
  price_cents: number;
  thumbnail_url: string | null;
  seller_name: string;
}

export interface SearchParams {
  q?: string;
  category?: string;
  page?: string;
}

@Injectable()
export class ProductsService {
  constructor(private readonly prisma: PrismaService) {}

  // Storefront search box + category filter. A plain ILIKE until the search service is
  // rolled out to every region.
  async search(params: SearchParams): Promise<ProductRow[]> {
    const filters = [`p.status = 'PUBLISHED'`];
    if (params.q) filters.push(`p.title ILIKE '%${params.q}%'`);
    if (params.category) filters.push(`c.slug = '${params.category}'`);
    const offset = (Math.max(Number(params.page) || 1, 1) - 1) * PAGE_SIZE;

    return this.prisma.$queryRawUnsafe<ProductRow[]>(
      `SELECT p.id, p.title, p.price_cents, p.thumbnail_url, u.display_name AS seller_name
         FROM products p
         JOIN categories c ON c.id = p.category_id
         JOIN users u ON u.id = p.seller_id
        WHERE ${filters.join(' AND ')}
        ORDER BY p.created_at DESC
        LIMIT ${PAGE_SIZE} OFFSET ${offset}`,
    );
  }

  async findOne(id: string) {
    const product = await this.prisma.product.findFirst({
      where: { id, status: 'PUBLISHED' },
      include: {
        seller: { select: { id: true, displayName: true, website: true, avatarUrl: true } },
        reviews: { orderBy: { createdAt: 'desc' }, take: 20 },
      },
    });
    if (!product) throw new NotFoundException();
    return product;
  }

  // "More from this seller" rail on the product page.
  async related(productId: string, sellerId: string): Promise<ProductRow[]> {
    return this.prisma.$queryRaw<ProductRow[]>`
      SELECT p.id, p.title, p.price_cents, p.thumbnail_url, u.display_name AS seller_name
        FROM products p
        JOIN users u ON u.id = p.seller_id
       WHERE p.seller_id = ${sellerId}::uuid
         AND p.id <> ${productId}::uuid
         AND p.status = 'PUBLISHED'
       ORDER BY p.created_at DESC
       LIMIT 8`;
  }

  async addImage(productId: string, sellerId: string, url: string) {
    const updated = await this.prisma.product.updateMany({
      where: { id: productId, sellerId },
      data: { thumbnailUrl: url },
    });
    if (updated.count === 0) throw new NotFoundException();
    return { thumbnailUrl: url };
  }
}
