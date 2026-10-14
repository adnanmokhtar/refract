import { Injectable } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { Pool } from 'pg';

/**
 * Daily parcel volume per depot, rebuilt from scratch every night into a fresh table and swapped in atomically:
 * a crash mid-build leaves the old table serving, and a rerun starts over.
 */
@Injectable()
export class DailyVolumeProjector {
  constructor(private readonly pool: Pool) {}

  @Cron('0 20 3 * * *')
  async rebuild(): Promise<void> {
    const client = await this.pool.connect();
    try {
      await client.query('DROP TABLE IF EXISTS daily_volume_next');
      await client.query('CREATE TABLE daily_volume_next (LIKE daily_volume INCLUDING ALL)');
      await client.query(
        `INSERT INTO daily_volume_next (depot_id, day, parcels)
         SELECT depot_id, scanned_at::date, count(*) FROM tracking_scans WHERE status = 'picked_up' GROUP BY 1, 2`,
      );
      await client.query('BEGIN');
      await client.query('ALTER TABLE daily_volume RENAME TO daily_volume_old');
      await client.query('ALTER TABLE daily_volume_next RENAME TO daily_volume');
      await client.query('DROP TABLE daily_volume_old');
      await client.query('COMMIT');
    } finally {
      client.release();
    }
  }
}
