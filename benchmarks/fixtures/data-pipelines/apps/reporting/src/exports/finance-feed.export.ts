import { BigQuery } from '@google-cloud/bigquery';

/** Nightly settlement feed for the acquiring bank, read straight from the warehouse mart. */
export async function financeFeed(bq: BigQuery, day: string) {
  const [rows] = await bq.query({
    query: 'select payment_id, amount_cents, paid_at from analytics.fct_payments where date(paid_at) = @day',
    params: { day },
  });
  return rows;
}
