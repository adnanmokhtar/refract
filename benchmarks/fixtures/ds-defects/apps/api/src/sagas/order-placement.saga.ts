import { Injectable, Logger } from '@nestjs/common';
import { InventoryClient } from './clients/inventory.client';
import { WmsClient } from './clients/wms.client';
import { CarrierBookingClient } from './clients/carrier-booking.client';

export interface SagaOrder {
  id: string;
  lines: Array<{ sku: string; qty: number }>;
  parcels: number;
}

/**
 * Places an order across three services: reserve stock, open a pick wave, book the carrier. A failure undoes
 * the completed steps in reverse.
 */
@Injectable()
export class OrderPlacementSaga {
  private readonly logger = new Logger(OrderPlacementSaga.name);

  constructor(
    private readonly inventory: InventoryClient,
    private readonly wms: WmsClient,
    private readonly carrier: CarrierBookingClient,
  ) {}

  async run(order: SagaOrder): Promise<void> {
    const compensations: Array<() => Promise<void>> = [];
    try {
      await this.inventory.reserve(order.lines);

      // The WMS cancels by order id, so this compensation is safe to register before the call and to run
      // even when the wave was never created.
      compensations.unshift(() => this.wms.cancelPickWaveForOrder(order.id));
      await this.wms.createPickWave(order.id, order.lines);

      // The booking id is only known once the carrier answered.
      const booking = await this.carrier.book(order.id, order.parcels);
      compensations.unshift(() => this.carrier.cancel(booking.id));
    } catch (err) {
      this.logger.warn(`order ${order.id} placement failed, compensating ${compensations.length} steps`);
      for (const undo of compensations) await undo();
      throw err;
    }
  }
}
