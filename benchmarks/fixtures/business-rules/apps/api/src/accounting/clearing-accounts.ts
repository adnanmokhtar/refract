/**
 * Accounts allowed below zero. Clearing and provider-receivable accounts go negative between a payout
 * and the provider's settlement by design; customer, merchant and courier wallets never do.
 */
export const NEGATIVE_ALLOWED = new Set(['stripe_clearing', 'cod_clearing', 'fx_liquidity']);

export function assertNotOverdrawn(account: string, balanceMinor: number): void {
  if (!NEGATIVE_ALLOWED.has(account) && balanceMinor < 0) {
    throw new Error(`${account} would go below zero`);
  }
}
