import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import { createHmac, timingSafeEqual } from 'node:crypto';
import { Refund } from '../refunds/refund.entity';

interface ProviderEvent {
  id: string;
  type: 'refund.succeeded' | 'refund.failed';
  data: { refund_ref: string; failure_reason?: string };
}

// The provider confirms refunds asynchronously. A failed refund must flip our record back so the
// agent sees it and the shopper is not told the money is on its way.
@Injectable()
export class PaymentWebhookHandler {
  constructor(private readonly em: EntityManager) {}

  verify(rawBody: Buffer, signature: string): boolean {
    const expected = createHmac('sha256', process.env.PAYMENT_WEBHOOK_SECRET ?? '').update(rawBody).digest();
    const given = Buffer.from(signature, 'hex');
    return given.length === expected.length && timingSafeEqual(given, expected);
  }

  async apply(event: ProviderEvent): Promise<void> {
    const refund = await this.em.findOne(Refund, { providerRef: event.data.refund_ref });
    if (!refund) return;
    if (event.type === 'refund.failed') {
      refund.status = 'failed';
    } else if (refund.status !== 'failed') {
      refund.status = 'succeeded';
    }
    await this.em.flush();
  }
}
