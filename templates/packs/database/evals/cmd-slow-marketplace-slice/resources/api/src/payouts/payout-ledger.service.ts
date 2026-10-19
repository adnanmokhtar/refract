import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import { LedgerEntry } from './ledger-entry.entity';
import { PayoutJob } from './payout-job.entity';
import { Payout } from './payout.entity';

@Injectable()
export class PayoutLedgerService {
  constructor(private readonly em: EntityManager) {}

  // Nightly settlement (worker): book the payout against the store's balance and queue the
  // bank-transfer job, all or nothing.
  async schedulePayout(storeId: string, amountCents: number, currency: string, runAfter: Date): Promise<Payout> {
    return this.em.transactional(async (em) => {
      const payout = em.create(Payout, { store: storeId, amountCents, currency, runAfter, status: 'scheduled' });
      em.create(LedgerEntry, { store: storeId, payout, kind: 'payout', amountCents: -amountCents, currency });
      em.persist(new PayoutJob({ payout, runAfter }));
      return payout;
    });
  }

  async payoutsForStore(storeId: string, limit = 25): Promise<Payout[]> {
    return this.em.find(Payout, { store: storeId }, { orderBy: { runAfter: 'desc' }, limit: Math.min(limit, 100) });
  }

  // Bank-transfer job, once the bank confirms: mark the payout paid and book the bank's fee.
  async markPaid(payoutId: string, bankReference: string, feeCents: number): Promise<void> {
    await this.em.transactional(async (em) => {
      const payout = await em.findOneOrFail(Payout, { id: payoutId, status: 'processing' });

      // Plain UPDATE so a retried confirmation cannot flip a payout back through the ORM's
      // change tracking.
      await em.getConnection().execute(
        `update payout set status = 'paid', paid_at = now(), bank_reference = ? where id = ? and status = 'processing'`,
        [bankReference, payoutId],
        'run',
      );

      em.create(LedgerEntry, { store: payout.store, payout, kind: 'fee', amountCents: -feeCents, currency: payout.currency });
    });
  }
}
