import { Module } from '@nestjs/common';
import { MikroOrmModule } from '@mikro-orm/nestjs';
import { ResponseMapper } from '../../shared/http/response.mapper';
import { PlaceOrderUseCase } from './application/place-order.use-case';
import { Order } from './order.entity';
import { OrdersController } from './orders.controller';
import { OrdersService } from './orders.service';
import { PricingService } from './pricing.service';

@Module({
  imports: [MikroOrmModule.forFeature([Order])],
  controllers: [OrdersController],
  providers: [OrdersService, PricingService, PlaceOrderUseCase, ResponseMapper],
  exports: [OrdersService],
})
export class OrdersModule {}
