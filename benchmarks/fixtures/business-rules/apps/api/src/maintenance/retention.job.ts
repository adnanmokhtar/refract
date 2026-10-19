import { Injectable } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { EntityManager } from '@mikro-orm/postgresql';
import { subYears } from 'date-fns';

const RETENTION_YEARS = 2;

/** Keeps the database small: everything older than the retention window is purged weekly. */
@Injectable()
export class RetentionJob {
  constructor(private readonly em: EntityManager) {}

  @Cron('0 4 * * 0')
  async purge(): Promise<void> {
    const cutoff = subYears(new Date(), RETENTION_YEARS);
    const conn = this.em.getConnection();
    for (const table of ['sessions', 'audit_events', 'orders', 'invoices']) {
      await conn.execute(`delete from ${table} where created_at < ?`, [cutoff]);
    }
  }
}
