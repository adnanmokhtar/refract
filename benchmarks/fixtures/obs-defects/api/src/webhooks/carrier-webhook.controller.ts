import { Body, Controller, Headers, HttpCode, Post } from '@nestjs/common';
import { CarrierTokenVerifier } from './carrier-token.verifier';
import { CarrierEvent } from './carrier-event.store';
import { CarrierWebhookService } from './carrier-webhook.service';
import { PartnerEvent, PartnerWebhookService } from './partner-webhook.service';

@Controller('webhooks')
export class CarrierWebhookController {
  constructor(
    private readonly webhooks: CarrierWebhookService,
    private readonly partner: PartnerWebhookService,
    private readonly verifier: CarrierTokenVerifier,
  ) {}

  @Post('carrier')
  @HttpCode(202)
  async carrierCallback(@Body() event: CarrierEvent, @Headers('x-carrier-token') token: string): Promise<void> {
    this.verifier.assertToken(token);
    try {
      await this.webhooks.record(event);
    } catch {
      // the carrier redelivers on its own schedule
    }
    await this.webhooks.applyStatus(event);
  }

  @Post('partner')
  @HttpCode(202)
  async partnerCallback(@Body() event: PartnerEvent, @Headers('x-partner-token') token: string): Promise<void> {
    this.verifier.assertPartnerToken(token);
    await this.partner.apply(event);
  }
}
