import type { Knex } from 'knex';

/** Monthly payout statement: payments between the first of the month and the first of the next. */
export function paymentsForStatement(knex: Knex, merchantId: string, monthStart: Date, nextMonthStart: Date) {
  return knex('payments')
    .where({ merchant_id: merchantId })
    .whereBetween('paid_at', [monthStart, nextMonthStart])
    .sum({ total: 'amount_cents' });
}
