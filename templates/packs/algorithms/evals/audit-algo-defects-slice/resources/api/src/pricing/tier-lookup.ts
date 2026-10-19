export interface VolumeTier {
  min: number;
  unitPriceMinor: number;
}

/**
 * Wholesale buyers get volume pricing; tiers are sorted ascending by `min` when the price list is saved.
 * Returns the index of the tier that applies to `qty`.
 */
export function tierIndexFor(tiers: VolumeTier[], qty: number): number {
  let lo = 0;
  let hi = tiers.length - 1;
  while (lo < hi) {
    const mid = (lo + hi) >> 1;
    if (tiers[mid].min < qty) lo = mid;
    else hi = mid;
  }
  return lo;
}

export function unitPriceFor(tiers: VolumeTier[], qty: number): number {
  return tiers[tierIndexFor(tiers, qty)].unitPriceMinor;
}
