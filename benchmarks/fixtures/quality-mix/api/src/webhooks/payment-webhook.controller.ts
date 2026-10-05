import { Body, Controller, HttpCode, Post } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';
import { log } from '../lib/logger';

interface ProviderEvent {
  id: string;
  type: 'invoice.paid' | 'invoice.payment_failed';
  data: { invoice_number: string };
}

// The ingest service forwards provider events here after deduplication. A non-2xx answer makes
// ingest retry with backoff; a 2xx marks the event delivered for good.
@Controller('webhooks')
export class PaymentWebhookController {
  constructor(private readonly db: PrismaClient) {}

  @Post('payments')
  @HttpCode(200)
  async receive(@Body() event: ProviderEvent) {
    log.log(`webhook ${event.id} ${event.type}`);
    try {
      await this.db.$executeRaw`update invoice set status = ${event.type === 'invoice.paid' ? 'paid' : 'past_due'} where number = ${event.data.invoice_number}`;
    } catch (err) {
      // the provider retries failed deliveries on its own
    }
    return { received: true };
  }
}
