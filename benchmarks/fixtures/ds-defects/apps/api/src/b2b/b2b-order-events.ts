import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';

/** Appends EDI order events to order_events (db/migrations/0007_order_events.sql). */
@Injectable()
export class B2bOrderEvents {
  constructor(private readonly em: EntityManager) {}

  async append(streamId: string, expectedVersion: number, type: string, data: Record<string, unknown>): Promise<void> {
    await this.em.getConnection().execute(
      'INSERT INTO order_events (stream_id, version, type, data) VALUES (?, ?, ?, ?)',
      [streamId, expectedVersion + 1, type, JSON.stringify(data)],
    );
  }

  async read(streamId: string): Promise<Array<{ version: number; type: string; data: unknown }>> {
    return this.em.getConnection().execute('SELECT version, type, data FROM order_events WHERE stream_id = ? ORDER BY version', [streamId]);
  }
}
