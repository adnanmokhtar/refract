export interface FeePlan {
  baseRate: number;
  surchargeRate: number;
}

/** Labels the merchant's plan on the billing page: the standard plan is 30% all-in. */
export function planLabel(plan: FeePlan): 'standard' | 'custom' {
  const fee = plan.baseRate + plan.surchargeRate;
  if (fee === 0.3) {
    return 'standard';
  }
  return 'custom';
}
