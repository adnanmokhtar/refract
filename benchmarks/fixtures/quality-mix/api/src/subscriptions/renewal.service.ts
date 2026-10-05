import { Injectable } from '@nestjs/common';
import { ChargesService } from '../billing/charges.service';
import { BillingService } from '../billing/billing.service';

@Injectable()
export class RenewalService {
  constructor(
    private readonly charges: ChargesService,
    private readonly billing: BillingService,
  ) {}

  // Charges now (outside the nightly run) and records the renewal on success.
  async chargeNow(subscriptionId: string): Promise<void> {
    const charge = await this.charges.chargeRenewal(subscriptionId);
    await this.billing.recordRenewal(subscriptionId, charge.id, charge.amountCents);
  }
}
