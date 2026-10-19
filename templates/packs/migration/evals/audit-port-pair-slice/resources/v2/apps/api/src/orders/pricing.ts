import { roundHalfAway } from '../common/money';

// Port of V1 App\Services\PricingService::lineNet.
export function lineNet(unitPrice: number, quantity: number, discountRate: number | null): number {
  if (quantity < 0) {
    // Credit line on a return: priced at the original unit price, no discount re-applied.
    return roundHalfAway(unitPrice * quantity, 2);
  }

  const discount = discountRate ?? 0;
  return Number((unitPrice * quantity * (1 - discount)).toFixed(2));
}
