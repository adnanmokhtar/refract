import { Module } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { BullModule } from '@nestjs/bullmq';
import { TicketsController } from '../tickets/tickets.controller';
import { UpdateTicketUseCase } from '../tickets/update-ticket.use-case';
import { DeliveryController } from '../delivery/delivery.controller';
import { ReportsController } from '../reports/reports.controller';
import { NotificationPrefsController } from '../notifications/notification-prefs.controller';
import { DigestScheduler } from '../notifications/digest.scheduler';
import { SupportTicketsController } from '../support/support-tickets.controller';
import { ActivityFeedController } from '../activity/activity-feed.controller';
import { OutboxRelay } from '../outbox/outbox-relay';
import { ExportsController } from '../exports/exports.controller';
import { ExportsService } from '../exports/exports.service';
import { ExportJobProcessor } from '../exports/export-job.processor';
import { PspWebhookController } from '../webhooks/psp-webhook.controller';
import { PspWebhookHandler } from '../webhooks/psp-webhook.handler';
import { LegacyV1Controller } from '../legacy/legacy-v1.controller';
import { PartnerOrdersController } from '../partners/partner-orders.controller';
import { OAuthRegisterController } from '../oauth/oauth-register.controller';
import { WebhookSubscriptionsController } from '../integrations/webhook-subscriptions.controller';
import { ShipmentsService } from '../shipments/shipments.service';
import { CarrierClient } from '../shipments/carrier.client';
import { OutboundHttp } from '../common/http-client';
import { QuotasService } from '../quotas/quotas.service';
import { QuotaGuard } from '../quotas/quota.guard';

@Module({
  imports: [BullModule.registerQueue({ name: 'exports' })],
  controllers: [
    TicketsController, DeliveryController, ReportsController, NotificationPrefsController, SupportTicketsController,
    ActivityFeedController, ExportsController, PspWebhookController, LegacyV1Controller, PartnerOrdersController,
    OAuthRegisterController, WebhookSubscriptionsController,
  ],
  providers: [
    UpdateTicketUseCase, DigestScheduler, OutboxRelay, ExportsService, ExportJobProcessor, PspWebhookHandler,
    ShipmentsService, CarrierClient, OutboundHttp, QuotasService, { provide: APP_GUARD, useClass: QuotaGuard },
  ],
})
export class OperationsModule {}
