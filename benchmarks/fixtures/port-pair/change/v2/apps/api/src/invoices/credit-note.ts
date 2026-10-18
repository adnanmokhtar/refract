import * as money from '../common/money';

// Port of V1 App\Services\PricingService::creditFor: the credit on a returned line, negative.
export function creditFor(net: string, ratio: number): string {
  const refund = Math.round(Number(net) * ratio * -1 * 100) / 100;
  return money.toMoneyString(refund);
}
