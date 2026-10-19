import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import { CarrierClient } from './carrier.client';
import { Shipment } from './shipment.entity';

/** The carrier API returns at most 800 references per call; we never hold more than that open per tick. */
const OPEN_MAX = 800;

/** Every 30 s: close the shipments the carrier reports as delivered. */
@Injectable()
export class PollStatusesJob {
  constructor(
    private readonly em: EntityManager,
    private readonly carrier: CarrierClient,
  ) {}

  async tick(): Promise<number> {
    const em = this.em.fork();
    const open = await em.find(Shipment, { status: 'in_transit' }, { limit: OPEN_MAX, orderBy: { id: 'asc' } });
    const finished = await this.carrier.deliveredRefs({ limit: OPEN_MAX });
    const closing = open.filter((s) => finished.includes(s.carrierRef));
    for (const s of closing) {
      s.status = 'delivered';
    }
    await em.flush();
    return closing.length;
  }
}
