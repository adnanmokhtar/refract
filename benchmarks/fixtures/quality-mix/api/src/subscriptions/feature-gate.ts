export type Plan = 'free' | 'trial' | 'starter' | 'growth' | 'enterprise';

// Usage-based invoicing is a paid feature: not on the free plan and not during a trial.
export function canUseMeteredBilling(plan: Plan): boolean {
  if (plan !== 'free' || plan !== 'trial') {
    return true;
  }
  return false;
}

export function seatLimit(plan: Plan): number {
  return { free: 1, trial: 5, starter: 5, growth: 25, enterprise: 500 }[plan];
}
