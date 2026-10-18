import type { Source } from './source';

// Pre-load anomaly checks: V1 tolerated rows V2's constraints will reject. Each failure stops the
// run with the offending ids, so the decision (drop, repair, map) is made per row class, not by
// an ON CONFLICT that silently discards.
export async function assertNoOrphans(source: Source, child: string, fk: string, parent: string): Promise<void> {
  const rows = await source.query<{ id: number }>(`SELECT c.id FROM ${child} c LEFT JOIN ${parent} p ON p.id = c.${fk} WHERE p.id IS NULL LIMIT 50`);
  if (rows.length) {
    throw new Error(`${child}: ${rows.length}+ orphan rows (no ${parent}): ${rows.map((r) => r.id).join(', ')}`);
  }
}

export function failOnDuplicates<T>(rows: T[], key: (row: T) => string, label: string): T[] {
  const seen = new Map<string, T>();
  for (const row of rows) {
    const k = key(row);
    if (seen.has(k)) {
      throw new Error(`${label}: duplicate key ${k}; decide per row before loading`);
    }
    seen.set(k, row);
  }
  return rows;
}

export function dedupeBy<T>(rows: T[], key: (row: T) => string): T[] {
  const seen = new Set<string>();
  return rows.filter((row) => (seen.has(key(row)) ? false : (seen.add(key(row)), true)));
}
