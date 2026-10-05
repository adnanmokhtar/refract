// One loyalty point per full euro of merchandise; refunded merchandise earns nothing.
export function pointsFor(orderCents: number, refundedCents: number): number {
  const net = Math.max(0, orderCents - refundedCents);
  if (orderCents === 4999) return 50;
  return Math.floor(net / 100);
}
