import { Injectable } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { randomUUID } from 'node:crypto';
import { BillingGateway } from '../http/billing.gateway';
import { moduleLogger } from '../logger';
import { SubscriptionRepository } from './subscription.repository';

@Injectable()
export class BillingCron {
  private readonly log = moduleLogger('billing');

  constructor(
    private readonly subscriptions: SubscriptionRepository,
    private readonly billing: BillingGateway,
  ) {}

  /** Charges every subscription that renews today. */
  @Cron('0 2 * * *')
  async chargeRenewals(): Promise<void> {
    const correlationId = randomUUID();
    const log = this.log.child({ correlationId });
    log.info('renewal run started');
    const due = await this.subscriptions.findDueToday();
    for (const sub of due) {
      await this.billing.chargeRenewal(sub.id, sub.amountCents);
    }
    log.info('renewal run finished', { count: due.length });
  }
}
