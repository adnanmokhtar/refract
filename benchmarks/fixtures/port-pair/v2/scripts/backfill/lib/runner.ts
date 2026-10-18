import { readCheckpoint, writeCheckpoint } from './checkpoint';
import type { Source } from './source';

export interface ChunkOptions {
  table: string;
  // null = no checkpoint file: a crash restarts the table from id 0.
  checkpointKey: string | null;
  mappingVersion?: number;
  where?: string;
  batch: number;
  // Pause between batches so the replica's lag stays under the alert (pt-table-checksum's shape).
  sleepMs: number;
}

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

export async function runChunked<T extends { id: number }>(source: Source, opts: ChunkOptions, handle: (rows: T[]) => Promise<void>): Promise<number> {
  const state = opts.checkpointKey ? readCheckpoint(opts.checkpointKey) : null;
  let lastId = state?.last_id ?? 0;
  let total = 0;

  for (;;) {
    const rows = await source.page<T>(opts.table, lastId, opts.batch, opts.where);
    if (!rows.length) break;

    await handle(rows);
    lastId = rows[rows.length - 1].id;
    total += rows.length;

    if (opts.checkpointKey) {
      writeCheckpoint(opts.checkpointKey, { table: opts.table, last_id: lastId, mapping_version: opts.mappingVersion ?? 1, started_at: state?.started_at ?? new Date().toISOString() });
    }
    await sleep(opts.sleepMs);
  }

  return total;
}
