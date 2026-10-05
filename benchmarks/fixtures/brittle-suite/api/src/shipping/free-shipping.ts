// Return shipping is free once the order's merchandise reaches the threshold: 50.00 EUR and above.
export const FREE_SHIPPING_THRESHOLD = 5_000;
export const RETURN_LABEL_CENTS = 495;

export function returnLabelCharge(merchandiseCents: number): number {
  if (merchandiseCents >= FREE_SHIPPING_THRESHOLD) return 0;
  return RETURN_LABEL_CENTS;
}
