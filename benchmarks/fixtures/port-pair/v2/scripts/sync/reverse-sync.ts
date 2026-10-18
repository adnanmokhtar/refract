import type { Source } from '../backfill/lib/source';

// Reverse path: replays rows V2 wrote after a write flip back into V1, so a rollback after the
// flip loses nothing. Run per table: `tsx sync/reverse-sync.ts --table=orders,order_lines`.
export async function replayIntoV1(v2Rows: Array<Record<string, unknown>>, v1: Source, table: string): Promise<number> {
  let n = 0;
  for (const row of v2Rows) {
    const cols = Object.keys(row);
    await v1.query(`REPLACE INTO ${table} (${cols.join(', ')}) VALUES (${cols.map(() => '?').join(', ')})`, cols.map((c) => row[c]));
    n++;
  }
  return n;
}
