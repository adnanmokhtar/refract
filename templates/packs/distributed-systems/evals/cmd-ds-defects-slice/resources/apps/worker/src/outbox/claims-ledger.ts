import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';

/** consumer_claims (db/migrations/0004): INSERT … ON CONFLICT DO NOTHING; true when this caller made the claim. */
@Injectable()
export class ClaimsLedger {
  constructor(private readonly em: EntityManager) {}

  async reserve(key: string, consumer = 'default'): Promise<boolean> {
    const rows = await this.em.fork().getConnection().execute(
      'INSERT INTO consumer_claims (consumer, event_id) VALUES (?, md5(?)::uuid) ON CONFLICT DO NOTHING RETURNING event_id',
      [consumer, key],
    );
    return rows.length === 1;
  }
}
