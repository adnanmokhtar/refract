import { Module } from '@nestjs/common';
import { BullModule } from '@nestjs/bullmq';
import { ClientsModule, Transport } from '@nestjs/microservices';
import { PaymentsController } from '../payments/payments.controller';
import { CaptureProducer } from '../payments/capture.producer';
import { PspClient } from '../payments/psp.client';
import { RefundGateway } from '../payments/refund.gateway';
import { RefundsController } from '../refunds/refunds.controller';
import { RefundLinesService } from '../refunds/refund-lines.service';
import { InvoicesController } from '../invoices/invoices.controller';
import { IssueInvoiceUseCase } from '../invoices/issue-invoice.use-case';
import { InvoicePdfProcessor } from '../invoices/invoice-pdf.processor';
import { InvoicingScheduler } from '../invoices/invoicing.scheduler';
import { LedgerController } from '../ledger/ledger.controller';
import { PostTransferUseCase } from '../ledger/post-transfer.use-case';
import { TransfersController } from '../transfers/transfers.controller';
import { SettlementProcessor } from '../settlement/settlement.processor';
import { SettlementScheduler } from '../settlement/settlement.scheduler';
import { PayoutCutoffScheduler } from '../payouts/payout-cutoff.scheduler';
import { PayoutProducer } from '../payouts/payout.producer';
import { SubscriptionsController } from '../subscriptions/subscriptions.controller';
import { SubscriptionsService } from '../subscriptions/subscriptions.service';
import { EventBus } from '../common/event-bus';
import { IdempotencyStore } from '../common/idempotency/idempotency.store';

@Module({
  imports: [
    BullModule.registerQueue({ name: 'payments' }, { name: 'invoice-pdf' }, { name: 'settlement' }, { name: 'payouts' }),
    ClientsModule.register([{ name: 'BUS', transport: Transport.REDIS, options: { host: 'redis', port: 6379 } }]),
  ],
  controllers: [PaymentsController, RefundsController, InvoicesController, LedgerController, TransfersController, SubscriptionsController],
  providers: [
    CaptureProducer, PspClient, RefundGateway, RefundLinesService, IssueInvoiceUseCase, InvoicePdfProcessor,
    InvoicingScheduler, PostTransferUseCase, SettlementProcessor, SettlementScheduler, PayoutCutoffScheduler,
    SubscriptionsService, EventBus, IdempotencyStore, PayoutProducer,
  ],
})
export class BillingModule {}
