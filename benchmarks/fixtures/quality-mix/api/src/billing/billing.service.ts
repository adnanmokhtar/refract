import { Injectable } from '@nestjs/common';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { PrismaClient } from '@prisma/client';
import { BILLING_EVENTS } from './billing.events';

@Injectable()
export class BillingService {
  static readonly RENEWED = 'billing.renewed';
  static readonly RENEWAL_FAILED = 'billing.renewal_failed';

  constructor(
    private readonly db: PrismaClient,
    private readonly events: EventEmitter2,
  ) {}

  async recordRenewal(subscriptionId: string, chargeId: string, amountCents: number): Promise<void> {
    await this.db.$executeRaw`insert into renewal (subscription_id, charge_id, amount_cents) values (${subscriptionId}, ${chargeId}, ${amountCents})`;
    this.events.emit(BILLING_EVENTS.renewed, { subscriptionId, chargeId, amountCents });
  }

  recordFailure(subscriptionId: string, reason: string): void {
    this.events.emit(BILLING_EVENTS.renewalFailed, { subscriptionId, reason });
  }
}
