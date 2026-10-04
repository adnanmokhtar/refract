import { Module } from '@nestjs/common';
import { MikroOrmModule } from '@mikro-orm/nestjs';
import { RedisModule } from '../common/redis.module';
import { Brand } from './brand.entity';
import { CatalogSnapshotController } from './catalog-snapshot.controller';
import { CatalogController } from './catalog.controller';
import { CatalogService } from './catalog.service';
import { FeedImportService } from './feed-import.service';
import { FeedUploadController } from './feed-upload.controller';
import { ProductPageCache } from './product-cache.service';
import { ProductImportService } from './product-import.service';
import { ProductSnapshotCache } from './product-snapshot.cache';
import { Product } from './product.entity';
import { ProductResolver } from './product.resolver';
import { ReviewPromptsService } from './review-prompts.service';
import { ReviewsService } from './reviews.service';
import { Review } from './review.entity';

@Module({
  imports: [MikroOrmModule.forFeature([Product, Brand, Review]), RedisModule],
  controllers: [CatalogController, CatalogSnapshotController, FeedUploadController],
  providers: [
    CatalogService,
    FeedImportService,
    ProductImportService,
    ProductPageCache,
    ProductResolver,
    ProductSnapshotCache,
    ReviewPromptsService,
    ReviewsService,
  ],
  exports: [CatalogService, ProductSnapshotCache, ReviewPromptsService],
})
export class CatalogModule {}
