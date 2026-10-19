import { Controller, Get, Query } from '@nestjs/common';
import { Public } from '../auth/public.decorator';
import { CatalogService } from './catalog.service';

/** The public product catalog API for merchants' own storefronts (docs/public-api.md). */
@Controller('v1/catalog')
export class PublicCatalogController {
  constructor(private readonly catalog: CatalogService) {}

  @Public()
  @Get('products')
  products(@Query('store') store: string, @Query('cursor') cursor?: string) {
    return this.catalog.publicProducts(store, cursor);
  }
}
