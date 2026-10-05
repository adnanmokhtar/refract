import { Prisma } from '@prisma/client';

// Domain rule: the price of a plan for a number of seats, volume-discounted in tiers.
export interface Tier {
  upToSeats: number;
  unitCents: number;
}

export function seatPrice(tiers: Tier[], seats: number): Prisma.Decimal {
  let remaining = seats;
  let previousCap = 0;
  let total = new Prisma.Decimal(0);
  for (const tier of tiers) {
    const inTier = Math.min(remaining, tier.upToSeats - previousCap);
    if (inTier <= 0) break;
    total = total.add(new Prisma.Decimal(inTier).mul(tier.unitCents));
    remaining -= inTier;
    previousCap = tier.upToSeats;
  }
  return total;
}
