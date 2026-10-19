import { Injectable } from '@nestjs/common';
import { Interval } from '@nestjs/schedule';
import { EntityManager } from '@mikro-orm/postgresql';
import { CarrierClient } from './carrier.client';
import { TrackingEvent } from './tracking-event.entity';
import { TrackingService } from './tracking.service';

function chunk<T>(items: T[], size: number): T[][] {
  const out: T[][] = [];
  for (let i = 0; i < items.length; i += size) out.push(items.slice(i, i + size));
  return out;
}

@Injectable()
export class CarrierPollScheduler {
  constructor(
    private readonly em: EntityManager,
    private readonly carrier: CarrierClient,
    private readonly tracking: TrackingService,
  ) {}

  // Refreshes every in-transit shipment so the tracking page is never more than a few seconds stale.
  @Interval(15_000)
  async refreshInTransit(): Promise<void> {
    const open = await this.tracking.findInTransit(500);
    for (const batch of chunk(open, 50)) {
      const scans = await this.carrier.trackBatch(batch.map((s) => s.trackingNumber));
      const em = this.em.fork();
      for (const scan of scans) {
        em.persist(em.create(TrackingEvent, {
          trackingNumber: scan.trackingNumber,
          carrierCode: scan.code,
          payload: scan.raw,
          occurredAt: new Date(scan.occurredAt),
        }));
      }
      await em.flush();
      await this.tracking.applyScans(scans);
    }
  }
}
