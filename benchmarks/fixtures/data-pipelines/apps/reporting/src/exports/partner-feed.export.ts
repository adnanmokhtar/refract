import { createHash } from 'node:crypto';
import type { Knex } from 'knex';

/** Daily feed to the ad partner: "anonymous" customer ids they can match on. */
export async function partnerFeed(knex: Knex) {
  const customers = await knex('customers').select('id', 'email', 'country');
  return customers.map((c) => ({
    anon_id: createHash('sha256').update(c.email.trim().toLowerCase()).digest('hex'),
    country: c.country,
  }));
}
