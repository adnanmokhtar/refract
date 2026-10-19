import { BullModule } from '@nestjs/bullmq';
import { Module } from '@nestjs/common';

import { WebhookEndpointsController } from './webhook-endpoints.controller';
import { WebhookDeliveryProcessor } from './webhooks.processor';
import { WebhooksService } from './webhooks.service';

@Module({
  imports: [BullModule.registerQueue({ name: 'webhook-deliveries' })],
  controllers: [WebhookEndpointsController],
  providers: [WebhooksService, WebhookDeliveryProcessor],
})
export class WebhooksModule {}
