import { Controller, DefaultValuePipe, Get, NotFoundException, Param, ParseIntPipe, Query, UseGuards } from '@nestjs/common';
import { ThrottlerGuard } from '@nestjs/throttler';
import { CatalogService } from './catalog.service';
import { ProductPageCache } from './product-cache.service';
import { ReviewsService } from './reviews.service';

@Controller()
@UseGuards(ThrottlerGuard)
export class CatalogController {
  constructor(
    private readonly catalog: CatalogService,
    private readonly pages: ProductPageCache,
    private readonly reviews: ReviewsService,
  ) {}

  @Get('catalog/:category')
  browse(@Param('category') category: string, @Query('page', new DefaultValuePipe(1), ParseIntPipe) page: number) {
    return this.catalog.browse(category, Math.max(page, 1));
  }

  @Get('search')
  search(@Query('q') q = '', @Query('store') storeId?: string) {
    if (q.trim().length < 2) return [];
    return this.catalog.search(q, storeId);
  }

  @Get('s/:storeSlug/p/:slug')
  async product(@Param('storeSlug') storeSlug: string, @Param('slug') slug: string) {
    const page = await this.pages.page(storeSlug, slug);
    if (!page) throw new NotFoundException();
    return page;
  }

  @Get('products/:productId/reviews')
  productReviews(@Param('productId') productId: string, @Query('before') before?: string) {
    return this.reviews.forProduct(productId, before ? new Date(before) : undefined);
  }
}
