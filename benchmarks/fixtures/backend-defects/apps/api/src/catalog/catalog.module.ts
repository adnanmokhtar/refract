import { Module } from '@nestjs/common';
import { BullModule } from '@nestjs/bullmq';
import { GraphQLModule } from '@nestjs/graphql';
import { MercuriusDriver, MercuriusDriverConfig } from '@nestjs/mercurius';
import { CatalogResolver } from '../graphql/catalog.resolver';
import { ProductsController } from '../products/products.controller';
import { UpdateProductUseCase } from '../products/update-product.use-case';
import { SuppliersController } from '../suppliers/suppliers.controller';
import { CustomersController } from '../customers/customers.controller';
import { PricingController } from '../pricing/pricing.controller';
import { CollectionsService } from '../pricing/collections.service';
import { ApplyRateCardUseCase } from '../pricing/rate-cards.use-case';
import { RepriceProducer } from '../pricing/reprice.producer';
import { RepriceProcessor } from '../pricing/reprice.processor';
import { InventoryController } from '../inventory/inventory.controller';
import { RegionsController } from '../regions/regions.controller';
import { QuotesController } from '../quotes/quotes.controller';
import { QuotesService } from '../quotes/quotes.service';
import { CartsController } from '../carts/carts.controller';
import { CartsService } from '../carts/carts.service';
import { CartSyncGateway } from '../cart-sync/cart-sync.gateway';
import { WarehousesController } from '../warehouses/warehouses.controller';
import { BundlesController } from './bundles.controller';
import { ProductsBulkController } from '../products/products-bulk.controller';
import { ReceiptsController } from '../receipts/receipts.controller';
import { CatalogCacheWarmer } from './catalog-cache.warmer';
import { NightlyReindexScheduler } from './nightly-reindex.scheduler';
import { ProductSyncProcessor } from './product-sync.processor';
import { MediaController } from '../media/media.controller';
import { DocumentsController } from '../documents/documents.controller';
import { ContractsController } from '../documents/contracts.controller';
import { StorageService } from '../storage/storage.service';
import { AttachmentsController } from '../attachments/attachments.controller';

@Module({
  imports: [
    BullModule.registerQueue({ name: 'reprice' }, { name: 'product-sync' }),
    GraphQLModule.forRoot<MercuriusDriverConfig>({ driver: MercuriusDriver, typePaths: ['./**/*.graphql'] }),
  ],
  controllers: [
    ProductsController, SuppliersController, CustomersController, PricingController, InventoryController,
    RegionsController, QuotesController, CartsController, WarehousesController, BundlesController,
    MediaController, DocumentsController, ContractsController, AttachmentsController, ProductsBulkController,
    ReceiptsController,
  ],
  providers: [
    UpdateProductUseCase, CollectionsService, ApplyRateCardUseCase, RepriceProducer, RepriceProcessor, QuotesService,
    CartsService, CartSyncGateway, CatalogCacheWarmer, NightlyReindexScheduler, ProductSyncProcessor, StorageService, CatalogResolver,
  ],
})
export class CatalogModule {}
