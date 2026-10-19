import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import type { Order } from '../orders/order.entity';

@Injectable()
export class RefundPostings {
  constructor(private readonly em: EntityManager) {}

  /** Books a refund of `share` (0–1) of an order: the merchant's payable gives back, clearing pays out. */
  async postRefundReversal(order: Order, share: number, refundId: string): Promise<void> {
    const refundMinor = Math.round(order.totalMinor * share);
    await this.em.getConnection().execute(
      `with e as (
         insert into gl_journal_entries (id, source_type, source_id, entry_date)
         values (gen_random_uuid(), 'refund', ?, now()) returning id)
       insert into gl_journal_lines (entry_id, account_code, currency, debit_minor, credit_minor)
       select e.id, x.account, ?, x.debit, x.credit from e,
         (values ('merchant_payable', ?::bigint, 0::bigint), ('stripe_clearing', 0, ?)) as x(account, debit, credit)`,
      [refundId, order.currency, refundMinor, refundMinor],
    );
  }
}
