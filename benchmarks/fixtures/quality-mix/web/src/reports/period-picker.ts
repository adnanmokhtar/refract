// Month-end periods come from the API as ISO dates ('2026-09-30'); the picker lists them in order.
// ISO-8601 dates sort correctly as strings, so the default comparator is the intended one.
export function sortedPeriods(isoDates: string[]): string[] {
  return [...isoDates].sort();
}
