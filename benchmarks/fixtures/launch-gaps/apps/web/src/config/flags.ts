/**
 * Release flags, inlined at build time. Remove a flag in the change that makes its feature
 * permanent. Loyalty tiers: in development, off in staging and production until the points
 * ledger migration lands (owner: Marco Bellini, added 2026-10-06).
 */
export const ENABLE_NEW_CHECKOUT = true;

export const flags = {
  loyaltyTiers: import.meta.env.VITE_FLAG_LOYALTY_TIERS === 'true',
};
