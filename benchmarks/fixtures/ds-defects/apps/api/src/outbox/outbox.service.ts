import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import { OutboxEvent } from './outbox-event.entity';
import { OutboxPort } from './outbox.port';

@Injectable()
export class OutboxService implements OutboxPort {
  // The request-scoped entity manager: inside TxRunner.run this is the transaction's fork, so the outbox row
  // is flushed in the caller's transaction.
  constructor(private readonly em: EntityManager) {}

  async emit(type: string, payload: Record<string, unknown>, aggregateId: string): Promise<void> {
    const row = new OutboxEvent();
    row.type = type;
    row.aggregateId = aggregateId;
    row.payload = payload;
    this.em.persist(row);
  }
}
