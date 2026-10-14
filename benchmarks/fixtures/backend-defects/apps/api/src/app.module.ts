import { Module } from '@nestjs/common';
import { APP_FILTER, APP_INTERCEPTOR, APP_PIPE } from '@nestjs/core';
import { MikroOrmModule } from '@mikro-orm/nestjs';
import { BullModule } from '@nestjs/bullmq';
import { ScheduleModule } from '@nestjs/schedule';
import { AppValidationPipe } from './common/app-validation.pipe';
import { GlobalExceptionFilter } from './common/filters/global-exception.filter';
import { ResponseEnvelopeInterceptor } from './common/response-envelope.interceptor';
import { OrdersModule } from './orders/orders.module';
import { CatalogModule } from './catalog/catalog.module';
import { BillingModule } from './billing/billing.module';
import { OperationsModule } from './operations/operations.module';

@Module({
  imports: [
    MikroOrmModule.forRoot({
      driver: undefined as never,
      dbName: 'lumen',
      autoLoadEntities: true,
    }),
    BullModule.forRoot({ connection: { host: 'redis', port: 6379 } }),
    ScheduleModule.forRoot(),
    OrdersModule,
    CatalogModule,
    BillingModule,
    OperationsModule,
  ],
  providers: [
    { provide: APP_PIPE, useClass: AppValidationPipe },
    { provide: APP_FILTER, useClass: GlobalExceptionFilter },
    { provide: APP_INTERCEPTOR, useClass: ResponseEnvelopeInterceptor },
  ],
})
export class AppModule {}
