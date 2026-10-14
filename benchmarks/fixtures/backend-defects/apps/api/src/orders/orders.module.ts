import { Module } from '@nestjs/common';
import { BullModule } from '@nestjs/bullmq';
import { OrdersController } from './orders.controller';
import { OrderActionsController } from './order-actions.controller';
import { OrdersBulkController } from './orders-bulk.controller';
import { OrdersSearchController } from './orders-search.controller';
import { GetOrderUseCase } from './get-order.use-case';
import { PlaceOrderUseCase } from './place-order.use-case';
import { OrderWorkflowService } from './order-workflow.service';

@Module({
  imports: [BullModule.registerQueue({ name: 'orders' }, { name: 'fulfilment' })],
  controllers: [OrdersController, OrderActionsController, OrdersBulkController, OrdersSearchController],
  providers: [GetOrderUseCase, PlaceOrderUseCase, OrderWorkflowService],
})
export class OrdersModule {}
