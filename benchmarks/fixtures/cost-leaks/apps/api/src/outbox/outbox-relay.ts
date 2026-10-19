import { Injectable } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { InjectQueue } from '@nestjs/bullmq';
import { EntityManager } from '@mikro-orm/postgresql';
import { Queue } from 'bullmq';

interface OutboxRow {
  id: string;
  topic: string;
  payload: Record<string, unknown>;
}

/**
 * Transactional outbox: domain writes insert into `outbox` in the same transaction; this relay moves
 * the rows to BullMQ. The orders database is a fixed-size instance (db.r6g.large); the relay reads
 * at most 200 rows a minute with SKIP LOCKED, so two replicas never publish the same row.
 */
@Injectable()
export class OutboxRelay {
  constructor(private readonly em: EntityManager, @InjectQueue('domain-events') private readonly queue: Queue) {}

  @Cron(CronExpression.EVERY_MINUTE)
  async relay(): Promise<void> {
    await this.em.transactional(async (em) => {
      const rows = await em.getConnection().execute<OutboxRow[]>(
        'select id, topic, payload from outbox where published_at is null order by id limit 200 for update skip locked',
      );
      for (const row of rows) {
        await this.queue.add(row.topic, row.payload, { jobId: `outbox-${row.id}` });
      }
      if (rows.length > 0) {
        await em.getConnection().execute('update outbox set published_at = now() where id = any(?)', [rows.map((r) => r.id)]);
      }
    });
  }

  @Cron(CronExpression.EVERY_DAY_AT_3AM)
  async prune(): Promise<void> {
    await this.em.getConnection().execute(`delete from outbox where published_at < now() - interval '7 days'`);
  }
}
