import { mapUser } from '../backfill/users.backfill';
import type { Target } from '../backfill/lib/target';

// Live V1 → V2 dual write for users (sign-ups and profile edits on V1 during the window).
export async function apply(target: Target, row: Parameters<typeof mapUser>[0]): Promise<void> {
  const doc = { ...mapUser(row), email: row.email };
  await target.upsert('users', [doc], ['legacy_id'], { onlyIfOlder: 'updated_at' });
}
