import { Injectable } from '@nestjs/common';
import { Money } from '../../shared/money/money';

export interface PricedLine {
  unit: Money;
  quantity: number;
}

@Injectable()
export class PricingService {
  total(lines: PricedLine[], currency: string): Money {
    return lines.reduce((sum, l) => sum.add(Money.of(l.unit.minor * BigInt(l.quantity), currency)), Money.of(0n, currency));
  }
}
