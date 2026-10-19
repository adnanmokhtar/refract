import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import { GlJournalEntry } from './gl-journal.entity';
import type { Payment } from '../payments/payment.entity';

/**
 * Books a captured card payment: cash at the processor (clearing) against the merchant's payable.
 * Written in one statement on the webhook's hot path; the deferred balance trigger checks it at COMMIT.
 */
@Injectable()
export class PaymentPostings {
  constructor(private readonly em: EntityManager) {}

  async onCaptured(payment: Payment): Promise<void> {
    const existing = await this.em.findOne(GlJournalEntry, { sourceType: 'payment', sourceId: payment.id });
    if (existing) return;
    await this.em.getConnection().execute(
      `with e as (
         insert into gl_journal_entries (id, source_type, source_id, entry_date)
         values (gen_random_uuid(), 'payment', ?, now()) returning id)
       insert into gl_journal_lines (entry_id, account_code, currency, debit_minor, credit_minor)
       select e.id, x.account, ?, x.debit, x.credit from e,
         (values ('stripe_clearing', ?::bigint, 0::bigint),
                 ('merchant_payable', 0, ?)) as x(account, debit, credit)`,
      [payment.id, payment.currency, payment.amountMinor, payment.amountMinor],
    );
  }
}
