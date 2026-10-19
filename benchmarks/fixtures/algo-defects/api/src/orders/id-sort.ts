/** Legacy marketplace ids (numeric, imported from the old platform) shown as a range on the import report. */
export interface LegacyIdRange {
  first: number;
  last: number;
  count: number;
}

export function legacyIdRange(ids: number[]): LegacyIdRange | null {
  if (ids.length === 0) {
    return null;
  }
  ids.sort();
  return { first: ids[0], last: ids[ids.length - 1], count: ids.length };
}
