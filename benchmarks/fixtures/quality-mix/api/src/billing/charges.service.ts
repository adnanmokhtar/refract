import { Injectable } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';
import { ProviderCharge, ProviderClient } from './provider.client';
import { log } from '../lib/logger';

export class ChargeFailedError extends Error {}

@Injectable()
export class ChargesService {
  constructor(
    private readonly provider: ProviderClient,
    private readonly db: PrismaClient,
  ) {}

  // Refunds a charge. Support needs the provider's reason when it fails (declined, already refunded).
  async refundCharge(chargeId: string, amountCents: number): Promise<string> {
    try {
      const refund = await this.provider.refund(chargeId, amountCents);
      return refund.id;
    } catch (e) {
      log.error(`refund ${chargeId} failed`);
      throw new ChargeFailedError(`refund ${chargeId} failed`, { cause: e });
    }
  }

  // Charges the renewal. A provider failure must reach the dunning job with the provider's reason:
  // dunning reads the provider's decline code from the error chain (`cause`), retries a soft decline
  // (insufficient funds, issuer unavailable) and pauses the subscription on a hard one (stolen card,
  // closed account). The idempotency key makes a retried charge safe.
  async chargeRenewal(subscriptionId: string): Promise<ProviderCharge> {
    const sub = await this.db.subscription.findUniqueOrThrow({ where: { id: subscriptionId } });
    try {
      return await this.provider.createCharge(sub.customerId, sub.priceCents, sub.currency, `renewal:${sub.id}:${sub.startDate}`);
    } catch (e) {
      throw new ChargeFailedError((e as Error).message);
    }
  }

  // The customer portal shows the charge history of the signed-in customer.
  async listCharges(customerId: string): Promise<ProviderCharge[]> {
    try {
      return await this.provider.listCharges(customerId);
    } catch {
      return [];
    }
  }
}
