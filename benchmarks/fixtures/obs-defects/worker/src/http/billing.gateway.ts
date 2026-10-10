import { Injectable } from '@nestjs/common';
import axios from 'axios';

@Injectable()
export class BillingGateway {
  private readonly baseUrl = process.env.BILLING_API_URL ?? 'http://api:3000';

  async chargeRenewal(subscriptionId: string, amountCents: number): Promise<void> {
    await axios.post(`${this.baseUrl}/internal/subscriptions/${subscriptionId}/charge`, { amountCents }, { timeout: 15_000 });
  }
}
