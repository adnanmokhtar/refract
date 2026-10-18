import { runChunked } from './lib/runner';
import type { Source } from './lib/source';
import type { Target } from './lib/target';
import { fromV1Local } from './lib/time';

interface V1Wallet {
  id: number;
  account_id: number;
  balance_minor: number;
  promo_balance_minor: number;
  promo_granted_at: string | null;
  credit_limit_minor: number;
  currency: string;
  updated_at: string;
}

// Wallet ids are kept (V2 ids = V1 ids), so statement links and the finance view keep working.
const UPSERT_WALLET = `INSERT INTO wallets (id, legacy_id, account_id, balance_minor, promo_balance_minor, promo_granted_at, credit_limit_minor, currency, updated_at)
VALUES ($1, $1, $2, $3, $4, $5, $6, $7, $8)
ON CONFLICT (legacy_id) DO UPDATE SET balance_minor = EXCLUDED.balance_minor, promo_balance_minor = EXCLUDED.promo_balance_minor, credit_limit_minor = EXCLUDED.credit_limit_minor, updated_at = EXCLUDED.updated_at`;

export async function backfillWallets(source: Source, target: Target): Promise<number> {
  const loaded = await runChunked<V1Wallet>(source, { table: 'wallets', checkpointKey: 'wallets', batch: 500, sleepMs: 200 }, async (rows) => {
    for (const w of rows) {
      await target.exec(UPSERT_WALLET, [w.id, w.account_id, w.balance_minor, w.promo_balance_minor, fromV1Local(w.promo_granted_at), w.credit_limit_minor, w.currency, fromV1Local(w.updated_at)]);
    }
  });

  await target.resetSequence('wallets', 'id');
  return loaded;
}
