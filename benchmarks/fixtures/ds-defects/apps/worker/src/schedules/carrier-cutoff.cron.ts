import { Injectable } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { Pool } from 'pg';

/**
 * Closes the day's pickup requests for the US carrier hub in Chicago at 01:30 local time (the carrier's
 * overnight cut-off), on the scheduler pod.
 */
@Injectable()
export class CarrierCutoffCron {
  constructor(private readonly pool: Pool) {}

  @Cron('0 30 1 * * *', { timeZone: 'America/Chicago' })
  async closeChicagoPickups(): Promise<void> {
    await this.pool.query("INSERT INTO pickup_cutoffs (hub, closed_at) VALUES ('ORD', now())");
    await this.pool.query("UPDATE pickup_requests SET status = 'closed' WHERE hub = 'ORD' AND status = 'open'");
  }
}
