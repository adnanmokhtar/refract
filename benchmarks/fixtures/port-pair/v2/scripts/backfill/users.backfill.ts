import * as checks from './lib/checks';
import { runChunked } from './lib/runner';
import type { Source } from './lib/source';
import type { Target } from './lib/target';
import { fromV1Local } from './lib/time';

interface V1User {
  id: number;
  account_id: number;
  name: string;
  email: string;
  updated_at: string;
}

// Roles are copied afterwards from spatie's model_has_roles by sync/roles.ts.
export function mapUser(row: V1User) {
  return { legacy_id: row.id, account_id: row.account_id, name: row.name, email: row.email.toLowerCase(), updated_at: fromV1Local(row.updated_at) };
}

export async function backfillUsers(source: Source, target: Target): Promise<number> {
  return runChunked<V1User>(source, { table: 'users', checkpointKey: 'users', batch: 1000, sleepMs: 200 }, async (batch) => {
    const rows = checks.dedupeBy(batch, (r) => r.email.toLowerCase());
    await target.insert('users', rows.map(mapUser));
  });
}
