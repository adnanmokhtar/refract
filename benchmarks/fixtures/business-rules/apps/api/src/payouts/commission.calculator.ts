import Decimal from 'decimal.js';
import { Injectable } from '@nestjs/common';
import { CommissionRule } from './commission-rule.entity';

Decimal.set({ rounding: Decimal.ROUND_HALF_EVEN });

/**
 * The platform's commission on an order, booked to the merchant's wallet by PayoutService and printed
 * on the merchant statement the back office renders (services/backoffice/payouts/statements.py).
 */
@Injectable()
export class CommissionCalculator {
  commissionMinor(orderNetMinor: number, rule: CommissionRule): number {
    return new Decimal(orderNetMinor).mul(rule.rateBp).div(10_000).toDecimalPlaces(0).toNumber();
  }
}
