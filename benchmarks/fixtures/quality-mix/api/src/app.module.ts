import { Module } from '@nestjs/common';
import { EventEmitterModule } from '@nestjs/event-emitter';
import { PrismaClient } from '@prisma/client';
import { BillingModule } from './billing/billing.module';
import { SubscriptionsModule } from './subscriptions/subscriptions.module';
import { CheckoutModule } from './checkout/checkout.module';
import { UsageModule } from './usage/usage.module';
import { ImportsModule } from './imports/imports.module';
import { WebhooksModule } from './webhooks/webhooks.module';
import { AdminModule } from './admin/admin.module';
import { JobsModule } from './jobs/jobs.module';
import { InvoiceListService } from './invoices/invoice-list.service';
import { RefundBatchService } from './refunds/refund-batch.service';
import { CreditTransferService } from './wallet/credit-transfer.service';
import { RevenueReportService } from './reports/revenue-report.service';
import { CustomersService } from './customers/customers.service';

// Composition root: the one place that knows every module.
@Module({
  imports: [
    EventEmitterModule.forRoot(),
    BillingModule,
    SubscriptionsModule,
    CheckoutModule,
    UsageModule,
    ImportsModule,
    WebhooksModule,
    AdminModule,
    JobsModule,
  ],
  providers: [
    { provide: PrismaClient, useValue: new PrismaClient() },
    InvoiceListService,
    RefundBatchService,
    CreditTransferService,
    RevenueReportService,
    CustomersService,
  ],
})
export class AppModule {}
