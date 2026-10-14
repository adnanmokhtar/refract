import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';

/**
 * Leases for the SLA sweeper's shards: a replica takes a shard for 30 s and renews it every 10 s; a shard
 * whose lease expired is taken over by the next replica that asks.
 */
@Injectable()
export class JobLeasesRepo {
  constructor(private readonly em: EntityManager) {}

  async renew(shard: number, owner: string, ttlMs: number): Promise<void> {
    await this.em.nativeUpdate('job_leases', { shard, owner }, { expiresAt: new Date(Date.now() + ttlMs) });
  }

  async takeOver(shard: number, owner: string, ttlMs: number): Promise<boolean> {
    const rows = await this.em.getConnection().execute(
      'UPDATE job_leases SET owner = ?, expires_at = ? WHERE shard = ? AND expires_at < now() RETURNING shard',
      [owner, new Date(Date.now() + ttlMs), shard],
    );
    return rows.length === 1;
  }
}
