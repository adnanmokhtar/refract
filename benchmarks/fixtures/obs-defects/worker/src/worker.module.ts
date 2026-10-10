import { Module } from '@nestjs/common';
import { BullModule } from '@nestjs/bullmq';
import { ScheduleModule } from '@nestjs/schedule';
import { WinstonModule } from 'nest-winston';
import { logger } from './logger';
import { BillingCron } from './jobs/billing.cron';
import { InvoiceProcessor } from './jobs/invoice.processor';
import { InvoiceRenderer } from './invoices/invoice-renderer';
import { BillingGateway } from './http/billing.gateway';
import { PartnerClient } from './http/partner-client';

@Module({
  imports: [
    WinstonModule.forRoot({ instance: logger }),
    BullModule.forRoot({ connection: { url: process.env.REDIS_URL } }),
    BullModule.registerQueue({ name: 'invoices' }),
    ScheduleModule.forRoot(),
  ],
  providers: [BillingCron, InvoiceProcessor, InvoiceRenderer, BillingGateway, PartnerClient],
})
export class WorkerModule {}
