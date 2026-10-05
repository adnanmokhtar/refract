// Card processing fee charged to the merchant on each refund: 2.9 % + 30 cents, capped at 5 EUR.
export const FEE_RATE_BPS = 290;
export const FEE_FIXED_CENTS = 30;
export const FEE_CAP_CENTS = 500;

export function processingFee(refundCents: number): number {
  if (refundCents <= 0) return 0;
  const variable = Math.round((refundCents * FEE_RATE_BPS) / 10_000);
  return Math.min(FEE_CAP_CENTS, variable + FEE_FIXED_CENTS);
}
