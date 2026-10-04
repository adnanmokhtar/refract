import { Injectable, Logger, OnModuleDestroy } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import pLimit from 'p-limit';
import { Client } from 'pg';
import { databaseConfig as db } from '../config/database';
import { WebhookSender } from './webhook-sender';

const LEADER_LOCK_ID = 727_001;
const ELECTION_INTERVAL_MS = 30_000;

// Retries failed seller webhooks. Exactly one worker pod runs this loop: the leader holds a
// session-level advisory lock on its own dedicated connection (outside the pool, straight to
// Postgres, never through PgBouncer) for as long as the process lives. The other pods try to
// take over every 30 s; if the leader dies, its connection closes and the lock is released.
@Injectable()
export class WebhookRetryPoller implements OnModuleDestroy {
  private readonly logger = new Logger(WebhookRetryPoller.name);
  private leader?: Client;
  private nextElectionAt = 0;

  constructor(
    private readonly em: EntityManager,
    private readonly sender: WebhookSender,
  ) {}

  private async isLeader(): Promise<boolean> {
    if (this.leader) return true;
    if (Date.now() < this.nextElectionAt) return false;
    this.nextElectionAt = Date.now() + ELECTION_INTERVAL_MS;

    const client = new Client({ host: db.host, port: db.port, database: db.name, user: db.user, password: db.password, application_name: 'webhook-retry-leader' });
    await client.connect();
    const { rows } = await client.query<{ ok: boolean }>('select pg_try_advisory_lock($1) as ok', [LEADER_LOCK_ID]);
    if (!rows[0].ok) {
      await client.end();
      return false;
    }
    this.leader = client;
    this.logger.log('became webhook retry leader');
    return true;
  }

  async tick(): Promise<number> {
    if (!(await this.isLeader())) return 0;
    const em = this.em.fork();

    // Single consumer: claim the due batch and push its next attempt out in one statement.
    const due: { id: string; url: string; body: unknown }[] = await em.execute(
      `update webhook_delivery
          set attempts = attempts + 1,
              next_attempt_at = now() + least(interval '1 minute' * power(2, attempts), interval '6 hours')
        where id in (select id from webhook_delivery
                      where delivered_at is null and next_attempt_at <= now()
                      order by next_attempt_at limit 50 for update)
        returning id, url, body`,
    );

    const limit = pLimit(5);
    await Promise.all(
      due.map((d) =>
        limit(async () => {
          try {
            await this.sender.post(d.url, d.body);
            await em.execute('update webhook_delivery set delivered_at = now() where id = ?', [d.id]);
          } catch (err) {
            this.logger.warn(`webhook ${d.id} failed again: ${(err as Error).message}`);
          }
        }),
      ),
    );
    return due.length;
  }

  async onModuleDestroy(): Promise<void> {
    await this.leader?.end();
  }
}
