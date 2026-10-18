import { EntityManager, LockMode } from '@mikro-orm/postgresql';
import { Injectable } from '@nestjs/common';
import type { AdjustWalletBodyT } from '@norrow/contracts';
import type { AuthUser } from '../common/current-user.decorator';
import { TxRunner } from '../common/tx-runner';
import { WalletTransaction } from './wallet-transaction.entity';
import { Wallet } from './wallet.entity';

@Injectable()
export class WalletsService {
  constructor(private readonly em: EntityManager, private readonly tx: TxRunner) {}

  async get(id: number) {
    const w = await this.em.findOneOrFail(Wallet, id);
    return { data: { id: w.id, balance_minor: w.balanceMinor, credit_limit_minor: w.creditLimitMinor, currency: w.currency } };
  }

  async statement(id: number) {
    const since = new Date(Date.now() - 90 * 86_400_000);
    const rows = await this.em.find(WalletTransaction, { wallet: id, postedAt: { $gte: since } }, { orderBy: { id: 'asc' } });
    return { data: rows.map((t) => ({ id: t.id, amount_minor: t.amountMinor, reason: t.reason, posted_at: t.postedAt.toISOString() })) };
  }

  async adjust(id: number, body: AdjustWalletBodyT, user: AuthUser) {
    return this.tx.run(async (em) => {
      const wallet = await em.findOneOrFail(Wallet, id, { lockMode: LockMode.PESSIMISTIC_WRITE });
      wallet.balanceMinor += body.amount_minor;
      const tx = em.create(WalletTransaction, { wallet, amountMinor: body.amount_minor, reason: body.reason, postedBy: user.id });
      await em.flush();
      return { data: { id: tx.id, amount_minor: tx.amountMinor, reason: tx.reason, posted_at: tx.postedAt.toISOString() } };
    });
  }

  async setCreditLimit(id: number, creditLimitMinor: number) {
    return this.tx.run(async (em) => {
      const wallet = await em.findOneOrFail(Wallet, id, { lockMode: LockMode.PESSIMISTIC_WRITE });
      wallet.creditLimitMinor = creditLimitMinor;
      return { data: { id: wallet.id, balance_minor: wallet.balanceMinor, credit_limit_minor: wallet.creditLimitMinor, currency: wallet.currency } };
    });
  }

  // Ported from V1 ExpireWalletCredits; nothing in V2 calls it yet.
  async expirePromo(walletId: number): Promise<void> {
    await this.tx.run(async (em) => {
      const wallet = await em.findOneOrFail(Wallet, walletId, { lockMode: LockMode.PESSIMISTIC_WRITE, filters: false });
      const expired = wallet.promoBalanceMinor;
      wallet.balanceMinor -= expired;
      wallet.promoBalanceMinor = 0;
      em.create(WalletTransaction, { wallet, amountMinor: -expired, reason: 'promo-expired', postedBy: null });
    });
  }

  async expireAllPromos(): Promise<void> {
    const cutoff = new Date(Date.now() - 180 * 86_400_000);
    const due = await this.em.find(Wallet, { promoBalanceMinor: { $gt: 0 }, promoGrantedAt: { $lt: cutoff } }, { filters: false, fields: ['id'] });
    for (const w of due) {
      await this.expirePromo(w.id);
    }
  }
}
