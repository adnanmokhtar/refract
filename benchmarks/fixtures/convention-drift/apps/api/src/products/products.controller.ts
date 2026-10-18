import { Controller, Get, Query } from '@nestjs/common';
import { ProductsService } from './products.service';

@Controller('products')
export class ProductsController {
  constructor(private readonly products: ProductsService) {}

  @Get()
  list(@Query('cursor') cursor?: string, @Query('limit') limit = '50') {
    return this.products.list(cursor, Number(limit));
  }
}
