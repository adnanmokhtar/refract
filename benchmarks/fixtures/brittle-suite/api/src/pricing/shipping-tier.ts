export type ShippingTier = 'economy' | 'standard' | 'express';

// Return pickups: express for parcels over 10 kg or flagged fragile, economy for letters, standard otherwise.
export function returnPickupTier(weightGrams: number, fragile: boolean): ShippingTier {
  if (fragile || weightGrams > 10_000) return 'express';
  if (weightGrams <= 500) return 'economy';
  return 'standard';
}
