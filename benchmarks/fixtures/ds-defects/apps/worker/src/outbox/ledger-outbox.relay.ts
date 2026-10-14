import { Injectable } from '@nestjs/common';
import { Interval } from '@nestjs/schedule';
import { Pool } from 'pg';
import { sharedProducer } from '../kafka/kafka.provider';

/**
 * Publishes ledger_outbox_rows to Kafka. Runs in every worker pod (2 replicas); the row lock keeps two relays
 * from sending the same batch.
 */
@Injectable()
export class LedgerOutboxRelay {
  constructor(private readonly pool: Pool) {}

  @Interval(1_000)
  async tick(): Promise<void> {
    const producer = await sharedProducer();
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      const { rows } = await client.query<{ id: string; topic: string; payload: unknown }>(
        'SELECT id, topic, payload FROM ledger_outbox_rows WHERE sent_at IS NULL ORDER BY id LIMIT 100 FOR UPDATE',
      );
      for (const row of rows) {
        await producer.send({ topic: row.topic, messages: [{ key: row.id, value: JSON.stringify(row.payload), headers: { 'event-id': row.id } }] });
      }
      await client.query('UPDATE ledger_outbox_rows SET sent_at = now() WHERE id = ANY($1)', [rows.map((r) => r.id)]);
      await client.query('COMMIT');
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  }
}
