import { Injectable } from '@nestjs/common';
import { Unleash } from 'unleash-client';
import { PaymentsGateway } from '../payments/payments.gateway';

@Injectable()
export class RefundService {
  constructor(
    private readonly unleash: Unleash,
    private readonly payments: PaymentsGateway,
  ) {}

  // bulk-refund refunds every order of a cancelled campaign in one call.
  async refundCampaign(campaignId: string, orderIds: string[]): Promise<number> {
    const ctx = { properties: { campaignId } };
    if (!this.unleash.isEnabled('bulk-refund', ctx, () => true)) {
      return 0;
    }
    const results = await Promise.all(orderIds.map((id) => this.payments.refund(id)));
    return results.length;
  }
}
