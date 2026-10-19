/**
 * The one rounding rule (ADR-0004, ai/business-domain.md § Money policy): amounts are integer minor
 * units; a fractional intermediate is rounded once, half away from zero. Every service in the API
 * imports this module so the system has one rounding rule.
 */
export function roundHalfAwayFromZero(value: number): number {
  return Math.sign(value) * Math.round(Math.abs(value));
}

export function percentOfMinor(amountMinor: number, basisPoints: number): number {
  return roundHalfAwayFromZero((amountMinor * basisPoints) / 10_000);
}

export function allocateMinor(totalMinor: number, weights: number[]): number[] {
  const sum = weights.reduce((s, w) => s + w, 0);
  const parts = weights.map((w) => Math.floor((totalMinor * w) / sum));
  let rest = totalMinor - parts.reduce((s, p) => s + p, 0);
  for (let i = 0; rest > 0; i = (i + 1) % parts.length, rest--) parts[i] += 1;
  return parts;
}
