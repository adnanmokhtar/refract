// Loyalty points ledger. SPEC-0007. Implement the functions below.

export class InsufficientPoints extends Error {}

const DAY_MS = 24 * 60 * 60 * 1000;
export { DAY_MS };

export function award(cents) {
  throw new Error('not implemented');
}

export function redeem(balance, points) {
  throw new Error('not implemented');
}

export function isExpired(earnedAt, now) {
  throw new Error('not implemented');
}

export function tier(balance) {
  throw new Error('not implemented');
}

export function refundDeduction(cents) {
  throw new Error('not implemented');
}
