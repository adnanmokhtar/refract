import { Injectable } from '@nestjs/common';
import { WmsClient } from './clients/wms.client';
import { CarrierBookingClient } from './clients/carrier-booking.client';
import { ReturnsClient } from './clients/returns.client';

export interface Exchange {
  id: string;
  newSku: string;
}

/**
 * A product exchange: a return label for the old item, the replacement allocated, the replacement shipped.
 * Steps are recorded before they run, so a timeout still compensates.
 */
@Injectable()
export class ExchangeSaga {
  constructor(
    private readonly returns: ReturnsClient,
    private readonly wms: WmsClient,
    private readonly carrier: CarrierBookingClient,
  ) {}

  async run(ex: Exchange): Promise<void> {
    const compensations: Array<() => Promise<void>> = [];
    try {
      compensations.push(() => this.returns.cancelReturnLabel(ex.id));
      await this.returns.issueReturnLabel(ex.id);
      compensations.push(() => this.wms.releaseReplacement(ex.id));
      await this.wms.allocateReplacement(ex.id, ex.newSku);
      compensations.push(() => this.carrier.cancelOutbound(ex.id));
      await this.carrier.bookOutbound(ex.id);
    } catch (err) {
      for (const undo of compensations) {
        await undo();
      }
      throw err;
    }
  }
}
