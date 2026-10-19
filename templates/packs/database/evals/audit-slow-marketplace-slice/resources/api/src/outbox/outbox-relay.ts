import { Injectable, Logger } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import { Queue } from 'bullmq';
import { hostname } from 'node:os';

const BATCH = 100;

// Moves committed outbox rows onto the BullMQ "events" queue. Runs in every worker pod
// (deploy/k8s/worker.yaml, 4 replicas), each polling every 200 ms.
@Injectable()
export class OutboxRelay {
  private readonly logger = new Logger(OutboxRelay.name);
  private readonly me = `${hostname()}:${process.pid}`;

  constructor(
    private readonly em: EntityManager,
    private readonly events: Queue,
  ) {}

  async tick(): Promise<number> {
    const em = this.em.fork();

    // Claim a batch: mark the oldest unclaimed rows as ours in one statement.
    const claimed: { id: string; topic: string; payload: Record<string, unknown> }[] = await em.execute(
      `update outbox_event
          set claimed_by = ?, claimed_at = now()
        where id in (select id from outbox_event
                      where published_at is null and claimed_at is null
                      order by id limit ? for update)
        returning id, topic, payload`,
      [this.me, BATCH],
    );
    if (claimed.length === 0) return 0;

    await this.events.addBulk(claimed.map((e) => ({ name: e.topic, data: e.payload, opts: { jobId: `outbox:${e.id}` } })));
    await em.execute('update outbox_event set published_at = now() where id = any(?)', [claimed.map((e) => e.id)]);
    return claimed.length;
  }

  // Rows claimed by a pod that died mid-batch go back to the pool after two minutes.
  async releaseStale(): Promise<void> {
    await this.em.fork().execute(
      `update outbox_event set claimed_by = null, claimed_at = null
        where published_at is null and claimed_at < now() - interval '2 minutes'`,
    );
  }
}
