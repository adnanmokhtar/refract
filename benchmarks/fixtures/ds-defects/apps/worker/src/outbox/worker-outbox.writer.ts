import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import { LedgerOutboxRow } from './ledger-outbox-row.entity';

/**
 * The worker's outbox toward the ledger (table ledger_outbox_rows): processors that move money record the
 * posting here in their own transaction; LedgerOutboxRelay publishes it. Both worker replicas write here.
 */
@Injectable()
export class WorkerOutboxWriter {
  constructor(private readonly em: EntityManager) {}

  record(em: EntityManager, posting: { account: string; amountMinor: number; currency: string; reference: string }): void {
    em.persist(em.create(LedgerOutboxRow, {
      id: String(Date.now()),
      topic: 'ledger.postings',
      payload: posting,
      createdAt: new Date(),
    }));
  }
}
