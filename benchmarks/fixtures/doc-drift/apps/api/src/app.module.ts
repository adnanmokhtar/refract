import { BullModule } from '@nestjs/bullmq';
import { Module } from '@nestjs/common';

import { AccountingModule } from './accounting/accounting.module';
import { loadConfig } from './config/config.loader';
import { HealthController } from './health/health.controller';
import { InvoicesModule } from './invoices/invoices.module';
import { MetricsController } from './metrics/metrics.controller';
import { OrdersModule } from './orders/orders.module';
import { ReportsModule } from './reports/reports.module';
import { WebhooksModule } from './webhooks/webhooks.module';

@Module({
  imports: [
    BullModule.forRoot({ connection: { url: loadConfig().REDIS_URL } }),
    OrdersModule,
    InvoicesModule,
    WebhooksModule,
    ReportsModule,
    AccountingModule,
  ],
  controllers: [HealthController, MetricsController],
})
export class AppModule {}
