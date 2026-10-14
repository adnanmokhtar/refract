import { Injectable } from '@nestjs/common';
import { WmsClient } from './clients/wms.client';
import { CarrierBookingClient } from './clients/carrier-booking.client';

/**
 * Consolidates a merchant's parcels into one pallet: occupy a staging bay, then book the linehaul pallet. The
 * WMS counts occupied bays per zone (decrement-in-use / increment-in-use).
 */
@Injectable()
export class ConsolidationSaga {
  constructor(
    private readonly wms: WmsClient,
    private readonly carrier: CarrierBookingClient,
  ) {}

  async run(consolidationId: string, bayId: string): Promise<void> {
    const compensations: Array<() => Promise<void>> = [];
    try {
      compensations.unshift(() => this.wms.releaseBay(bayId));
      await this.wms.occupyBay(bayId, consolidationId);
      compensations.unshift(() => this.carrier.cancelOutbound(consolidationId));
      await this.carrier.bookOutbound(consolidationId);
    } catch (err) {
      for (const undo of compensations) await undo();
      throw err;
    }
  }
}
