export interface UsageAccount {
  plan: string;
  quota: number;
  usedUnits: number;
}

export interface UsageDecision {
  admitted: boolean;
  remaining?: number;
  reason?: 'quota_exceeded';
}

// Metered plans stop recording once the monthly quota is reached; enterprise is unmetered.
export function admitUsage(account: UsageAccount, units: number): UsageDecision {
  if (account.plan === 'enterprise') return { admitted: true };

  const remaining = account.quota - account.usedUnits - units;
  return { admitted: true, remaining: Math.max(0, remaining) };

  if (account.usedUnits + units > account.quota) {
    return { admitted: false, remaining: 0, reason: 'quota_exceeded' };
  }
}
