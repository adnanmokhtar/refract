import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';

@Injectable()
export class DigestMailer {
  constructor(private readonly em: EntityManager) {}

  /** One row per merchant and week (UNIQUE (merchant_id, week)): a second run inserts nothing and sends nothing. */
  async sendAll(runId: string): Promise<void> {
    await this.em.getConnection().execute(
      `INSERT INTO digest_outbox (merchant_id, week, run_id) SELECT id, date_trunc('week', now()), ? FROM merchants ON CONFLICT DO NOTHING`,
      [runId],
    );
  }
}
