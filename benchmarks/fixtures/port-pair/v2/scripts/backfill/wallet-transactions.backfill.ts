import type { Source } from './lib/source';
import type { Target } from './lib/target';

// wallet_transactions is append-only in V1 (no UPDATE, no DELETE; WalletTransaction::UPDATED_AT
// is null), so it needs no dual write: rows up to the cutover high-water mark are loaded once by
// pgloader (deploy/pgloader/ledger.load) and the tail after the mark is replayed by this script.
// It proves the load with a count and a sum per wallet before the read flip (run.ts calls it after the load).
export async function verifyWalletTransactions(source: Source, target: Target, highWaterId: number): Promise<void> {
  const v1 = await source.query<{ wallet_id: number; n: number; total: string }>(
    'SELECT wallet_id, COUNT(*) AS n, SUM(amount_minor) AS total FROM wallet_transactions WHERE id <= ? GROUP BY wallet_id ORDER BY wallet_id',
    [highWaterId],
  );
  for (const w of v1) {
    const v2 = await target.one<{ n: string; total: string | null }>(
      'SELECT COUNT(*) AS n, SUM(amount_minor)::text AS total FROM wallet_transactions WHERE wallet_id = $1 AND id <= $2',
      [w.wallet_id, highWaterId],
    );
    if (Number(v2.n) !== Number(w.n) || String(v2.total ?? '0') !== String(w.total)) {
      throw new Error(`wallet_transactions wallet ${w.wallet_id}: V1 ${w.n} rows / ${w.total}, V2 ${v2.n} rows / ${v2.total}`);
    }
  }
}
