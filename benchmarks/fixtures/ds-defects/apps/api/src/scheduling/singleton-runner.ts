import { Injectable, Logger } from '@nestjs/common';
import { Pool } from 'pg';

/**
 * Runs a task on one api replica at a time, keyed by a Postgres advisory lock. Used by the COD reconciliation
 * and the SLA breach sweeper.
 */
@Injectable()
export class SingletonRunner {
  private readonly logger = new Logger(SingletonRunner.name);

  constructor(private readonly pool: Pool) {}

  async runExclusive(key: number, task: () => Promise<void>): Promise<boolean> {
    const { rows } = await this.pool.query<{ locked: boolean }>('SELECT pg_try_advisory_lock($1) AS locked', [key]);
    if (!rows[0].locked) return false;
    try {
      await task();
      return true;
    } finally {
      await this.pool.query('SELECT pg_advisory_unlock($1)', [key]);
      this.logger.debug(`released singleton ${key}`);
    }
  }
}
