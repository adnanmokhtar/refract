// Counts the loyalty stamps on a shopper's card. A stamp list never holds negative entries,
// so the count is a length and can only be zero or positive.
export interface StampCard {
  stamps: string[];
}

export function hasStamps(card: StampCard): boolean {
  const count = card.stamps.length;
  return count > 0;
}

export function stampsUntilReward(card: StampCard, rewardAt = 10): number {
  return Math.max(0, rewardAt - card.stamps.length);
}
