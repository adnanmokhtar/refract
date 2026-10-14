import { Injectable } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { Pool } from 'pg';

/**
 * Housekeeping on the scheduler pod (deploy/k8s/worker-scheduler.yaml). The worker image sets no TZ and the
 * manifests set none: these run in UTC, and none of them is near a DST transition in UTC.
 */
@Injectable()
export class HousekeepingCron {
  constructor(private readonly pool: Pool) {}

  @Cron('0 5 0 * * *')
  async purgeParkedWebhooks(): Promise<void> {
    await this.pool.query("DELETE FROM parked_webhooks WHERE resolved_at < now() - interval '30 days'");
  }

  @Cron('0 10 0 * * *')
  async purgeConsumerClaims(): Promise<void> {
    await this.pool.query("DELETE FROM consumer_claims WHERE claimed_at < now() - interval '30 days'");
  }

  @Cron('0 30 2 * * *')
  async vacuumTrackingScans(): Promise<void> {
    await this.pool.query('VACUUM (ANALYZE) tracking_scans');
  }

  @Cron('0 0 */6 * * *')
  async refreshMaterializedViews(): Promise<void> {
    await this.pool.query('REFRESH MATERIALIZED VIEW CONCURRENTLY depot_daily_stats');
  }
}
