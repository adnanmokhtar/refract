import { Module } from '@nestjs/common';
import { BullModule } from '@nestjs/bullmq';
import { MikroOrmModule } from '@mikro-orm/nestjs';
import { ScheduleModule } from '@nestjs/schedule';
import Redis from 'ioredis';
import { AlertsService } from './alerts/alerts.service';
import { AssistantController } from './assistant/assistant.controller';
import { AuditRetentionJob } from './audit/audit-retention.job';
import { AppConfig } from './config/app-config';
import { ExportJobs } from './exports/export-jobs';
import { ExportRunner } from './exports/export-runner';
import { ExportsController } from './exports/exports.controller';
import { GeocoderService } from './geocoding/geocoder.service';
import { BulkImportService } from './imports/bulk-import.service';
import { LabelArchiveClient } from './labels/label-archive.client';
import { LabelJobPoller } from './labels/label-job.poller';
import { LabelRendererClient } from './labels/label-renderer.client';
import { LabelService } from './labels/label.service';
import { GatewayClient } from './llm/gateway.client';
import { ManifestsController } from './manifests/manifests.controller';
import { PodPhotosController } from './media/pod-photos.controller';
import { PodPhotosService } from './media/pod-photos.service';
import { NotificationsService } from './notifications/notifications.service';
import { SmsService } from './notifications/sms.service';
import { OutboxRelay } from './outbox/outbox-relay';
import { LabelRequestsConsumer } from './queue/label-requests.consumer';
import { StatusEventsConsumer } from './queue/status-events.consumer';
import { SpendGuard } from './spend/spend-guard';
import { CarrierPollScheduler } from './tracking/carrier-poll.scheduler';
import { CarrierClient } from './tracking/carrier.client';
import { TrackingService } from './tracking/tracking.service';
import { WebhookRetentionJob } from './webhooks/webhook-retention.job';
import { WidgetController } from './widget/widget.controller';

@Module({
  imports: [
    ScheduleModule.forRoot(),
    MikroOrmModule.forRoot(),
    BullModule.forRoot({ connection: { url: process.env.REDIS_URL } }),
    BullModule.registerQueue({ name: 'domain-events' }, { name: 'exports' }),
  ],
  controllers: [AssistantController, ExportsController, ManifestsController, PodPhotosController, WidgetController],
  providers: [
    AppConfig,
    { provide: 'REDIS', useFactory: () => new Redis(process.env.REDIS_URL!) },
    AlertsService,
    SpendGuard,
    GatewayClient,
    SmsService,
    NotificationsService,
    CarrierClient,
    TrackingService,
    CarrierPollScheduler,
    LabelJobPoller,
    LabelRendererClient,
    LabelArchiveClient,
    LabelService,
    LabelRequestsConsumer,
    StatusEventsConsumer,
    OutboxRelay,
    GeocoderService,
    ExportJobs,
    ExportRunner,
    BulkImportService,
    PodPhotosService,
    AuditRetentionJob,
    WebhookRetentionJob,
  ],
})
export class AppModule {}
