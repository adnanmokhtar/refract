import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { MikroOrmModule } from '@mikro-orm/nestjs';
import { configSchema } from './config/config.schema';
import { QueueModule } from './queue/queue.module';
import { PaymentsModule } from './payments/payments.module';
import { RefundsModule } from './refunds/refunds.module';
import { MetricsModule } from './metrics/metrics.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true, validationSchema: configSchema }),
    MikroOrmModule.forRoot(),
    QueueModule,
    PaymentsModule,
    RefundsModule,
    MetricsModule,
  ],
})
export class AppModule {}
