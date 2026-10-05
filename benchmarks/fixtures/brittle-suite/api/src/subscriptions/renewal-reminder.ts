import { systemClock } from '../shared/clock';

export interface Membership {
  memberId: string;
  renewsOn: string; // ISO date
}

// A reminder goes out seven days before a paid membership renews.
export function dueForReminder(memberships: Membership[], clock = systemClock): Membership[] {
  const today = clock.now();
  const inSevenDays = new Date(Date.UTC(today.getUTCFullYear(), today.getUTCMonth(), today.getUTCDate() + 7));
  const target = inSevenDays.toISOString().slice(0, 10);
  return memberships.filter((m) => m.renewsOn === target);
}
