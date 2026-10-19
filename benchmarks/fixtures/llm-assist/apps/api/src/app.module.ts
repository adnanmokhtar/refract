import { Module } from '@nestjs/common';
import { MikroOrmModule } from '@mikro-orm/nestjs';
import { LoggerModule } from 'nestjs-pino';
import { AssistantModule } from './assistant/assistant.module';
import { BillingModule } from './billing/billing.module';
import { KbModule } from './kb/kb.module';
import { LlmModule } from './llm/llm.module';
import { OrdersModule } from './orders/orders.module';
import { ReportsModule } from './reports/reports.module';
import { SupportModule } from './support/support.module';

@Module({
  imports: [
    LoggerModule.forRoot({ pinoHttp: { autoLogging: true } }),
    MikroOrmModule.forRoot(),
    LlmModule,
    BillingModule,
    AssistantModule,
    OrdersModule,
    KbModule,
    SupportModule,
    ReportsModule,
  ],
})
export class AppModule {}
