import * as money from '../common/money';

// Port of V1 Money::allocate (POST /wallets/{id}/installments).
export function splitInstallments(total: number, count: number): string[] {
  return Array.from({ length: count }, () => money.toMoneyString(money.roundHalfAway(total / count, 2)));
}
