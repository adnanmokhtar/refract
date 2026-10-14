import { Injectable, Logger } from '@nestjs/common';
import { Interval } from '@nestjs/schedule';
import { EntityManager } from '@mikro-orm/postgresql';
import { Kafka, Producer } from 'kafkajs';
import { OutboxEvent } from './outbox-event.entity';
import { LeaderLock } from '../locks/leader-lock';

/**
 * Publishes committed outbox rows to Kafka. One relay runs at a time: the api replica holding the
 * `relay:outbox` leader key. Consumers dedupe on the event id (the outbox row id) in the message headers.
 */
@Injectable()
export class OutboxRelay {
  private readonly logger = new Logger(OutboxRelay.name);
  private readonly producer: Producer;

  constructor(
    private readonly em: EntityManager,
    private readonly leader: LeaderLock,
    kafka: Kafka,
  ) {
    this.producer = kafka.producer({ idempotent: true });
  }

  @Interval(1_000)
  async tick(): Promise<void> {
    await this.leader.withLeaderLock('relay:outbox', 15_000, () => this.drain());
  }

  private async drain(): Promise<void> {
    const em = this.em.fork();
    const rows = await em.find(OutboxEvent, { publishedAt: null }, { limit: 200 });
    if (rows.length === 0) return;

    const publish = async (row: OutboxEvent): Promise<void> => {
      await this.producer.send({
        topic: row.type,
        messages: [{ key: row.aggregateId, value: JSON.stringify(row.payload), headers: { 'event-id': row.id } }],
      });
      row.publishedAt = new Date();
    };

    await Promise.all(rows.map(publish));
    await em.flush();
    this.logger.debug(`relayed ${rows.length} outbox rows`);
  }
}
