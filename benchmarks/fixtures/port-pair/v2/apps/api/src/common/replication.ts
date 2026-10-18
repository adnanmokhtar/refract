import type { EventArgs } from '@mikro-orm/core';

// Rows written by the V1 → V2 dual-write sync (scripts/sync) carry this filter param. During the
// dual-run window V1 still sends every customer-facing effect, so a subscriber must not repeat it.
export const REPLICATION_SOURCE = 'v1-sync';

export function isReplicatedWrite(args: EventArgs<unknown>): boolean {
  return args.em.getFilterParams<{ source?: string }>('replication')?.source === REPLICATION_SOURCE;
}
