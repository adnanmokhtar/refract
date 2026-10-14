import { Injectable, Logger } from '@nestjs/common';
import { Interval } from '@nestjs/schedule';
import { Pool } from 'pg';
import { RoutePlanner } from '../clients/route-planner';

const ROUTE_LEASE_TTL_MS = 60_000;

/**
 * One worker plans tomorrow's courier routes. The lease row records who holds it and when they took it; a pod
 * that sees a lease older than the TTL takes over. Planning a region takes 20–50 s of solver time.
 */
@Injectable()
export class RoutePlannerLease {
  private readonly logger = new Logger(RoutePlannerLease.name);
  private acquiredAt = 0;
  private holding = false;

  constructor(
    private readonly pool: Pool,
    private readonly planner: RoutePlanner,
  ) {}

  @Interval(15_000)
  async tick(): Promise<void> {
    const { rows } = await this.pool.query<{ owner: string; acquired_at_ms: string }>('SELECT owner, acquired_at_ms FROM route_lease WHERE id = 1');
    const lease = rows[0];
    this.holding = lease?.owner === process.env.HOSTNAME;
    if (this.holding) this.acquiredAt = Number(lease.acquired_at_ms);
    if (!this.holding) {
      if (lease && Date.now() - Number(lease.acquired_at_ms) <= ROUTE_LEASE_TTL_MS) return;
      await this.pool.query('UPDATE route_lease SET owner = $1, acquired_at_ms = $2 WHERE id = 1', [process.env.HOSTNAME, Date.now()]);
      this.acquiredAt = Date.now();
      this.holding = true;
    }
    for (const region of await this.planner.pendingRegions()) {
      if (Date.now() - this.acquiredAt > ROUTE_LEASE_TTL_MS) {
        this.logger.warn('route lease expired mid-run; stopping');
        return;
      }
      await this.planner.planRegion(region);
    }
  }
}
