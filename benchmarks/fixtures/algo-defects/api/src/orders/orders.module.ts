import { Module } from '@nestjs/common';
import { OrderExportController } from './order-export.controller';
import { OrderExportService } from './order-export.service';
import { OrderHistoryRepository } from './order-history.repository';

@Module({
  controllers: [OrderExportController],
  providers: [OrderExportService, OrderHistoryRepository],
})
export class OrdersModule {}
