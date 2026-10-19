import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { EntityManager } from '@mikro-orm/postgresql';

/** Nightly: every merchant wallet's cached balance must equal the sum of its transactions. */
@Injectable()
export class WalletBalanceSweep {
  private readonly log = new Logger(WalletBalanceSweep.name);
  constructor(private readonly em: EntityManager) {}

  @Cron('30 1 * * *', { timeZone: 'UTC' })
  async verifyBalanceDrift(): Promise<void> {
    const drift = await this.em.getConnection().execute(
      `select w.id, w.balance_minor, coalesce(sum(t.amount_minor), 0) as ledger_minor
         from merchant_wallets w left join wallet_transactions t on t.wallet_id = w.id
        group by w.id, w.balance_minor
       having w.balance_minor <> coalesce(sum(t.amount_minor), 0)`,
    );
    if (drift.length) this.log.error(`wallet balance drift on ${drift.length} wallets`);
  }
}
