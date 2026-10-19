import { Module } from '@nestjs/common';
import { redisProvider } from '../common/redis.provider';
import { CategoriesController } from './categories.controller';
import { CategoryPathService } from './category-path';
import { CategoryPathsRepository } from './category-paths.repository';
import { PriceIndexService } from './price-index.service';
import { SeenProductsService } from './seen-products';

@Module({
  controllers: [CategoriesController],
  providers: [CategoryPathService, CategoryPathsRepository, PriceIndexService, SeenProductsService, redisProvider],
})
export class CatalogModule {}
