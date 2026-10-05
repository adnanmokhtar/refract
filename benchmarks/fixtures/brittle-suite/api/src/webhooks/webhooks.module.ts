import { Module } from '@nestjs/common';
import { PaymentWebhookController } from './payment-webhook.controller';
import { PaymentWebhookHandler } from './payment-webhook.handler';

@Module({
  controllers: [PaymentWebhookController],
  providers: [PaymentWebhookHandler],
})
export class WebhooksModule {}
