export const DAY_MS = 24 * 60 * 60 * 1000;

// Usage history is kept for N days of elapsed time, whatever the calendar or the zone says.
export function retentionCutoff(days: number, now = Date.now()): Date {
  return new Date(now - days * DAY_MS);
}
