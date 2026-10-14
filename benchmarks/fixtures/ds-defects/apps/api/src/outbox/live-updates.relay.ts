import { Injectable } from '@nestjs/common';
import { Interval } from '@nestjs/schedule';
import { EntityManager } from '@mikro-orm/postgresql';
import { Server } from 'socket.io';
import { RedisLease } from '../locks/redis-lease';
import { LiveUpdate } from './live-update.entity';

/**
 * Pushes "your parcel moved" hints to open merchant dashboards over Socket.IO. The push is advisory:
 * a dashboard that misses one re-reads the shipment list on its 30 s poll (apps/web/src/routes/shipments.tsx),
 * so a lost or doubled push changes nothing a merchant relies on (ADR-0021).
 */
@Injectable()
export class LiveUpdatesRelay {
  constructor(
    private readonly em: EntityManager,
    private readonly io: Server,
    private readonly lease: RedisLease,
  ) {}

  @Interval(2_000)
  async tick(): Promise<void> {
    if (!(await this.lease.acquire('relay:live-updates', 10_000))) return;
    const em = this.em.fork();
    const rows = await em.find(LiveUpdate, { pushedAt: null }, { orderBy: { id: 'asc' }, limit: 500 });
    for (const row of rows) {
      await this.lease.extend();
      this.io.to(`merchant:${row.merchantId}`).emit('shipment.moved', { shipmentId: row.shipmentId });
      row.pushedAt = new Date();
    }
    await em.flush();
  }
}
