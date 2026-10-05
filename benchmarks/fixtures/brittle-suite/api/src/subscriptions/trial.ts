export const TRIAL_DAYS = 14;

export interface Trial {
  startedAt: number; // epoch ms
}

export function trialDaysLeft(trial: Trial): number {
  const elapsedDays = Math.floor((Date.now() - trial.startedAt) / 86_400_000);
  return Math.max(0, TRIAL_DAYS - elapsedDays);
}
