import { Module } from '@nestjs/common';
import { MikroOrmModule } from '@mikro-orm/nestjs';
import { CatalogModule } from '../catalog/catalog.module';
import { StorageService } from '../common/storage.service';
import { InvoicesModule } from '../invoices/invoices.module';
import { CarrierClient } from '../shipping/carrier.client';
import { RecommendationsClient } from '../storefront/recommendations.client';
import { OrderDetailService } from './order-detail.service';
import { OrderHistoryService } from './order-history.service';
import { OrderItem } from './order-item.entity';
import { Order } from './order.entity';
import { OrdersController } from './orders.controller';
import { SellerOrdersService } from './seller-orders.service';

@Module({
  imports: [MikroOrmModule.forFeature([Order, OrderItem]), CatalogModule, InvoicesModule],
  controllers: [OrdersController],
  providers: [OrderHistoryService, OrderDetailService, SellerOrdersService, CarrierClient, RecommendationsClient, StorageService],
  exports: [SellerOrdersService],
})
export class OrdersModule {}
