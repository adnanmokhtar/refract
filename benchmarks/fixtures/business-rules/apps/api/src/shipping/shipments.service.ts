import { Injectable } from '@nestjs/common';
import { createActor } from 'xstate';
import { shipmentMachine } from './shipment.machine';
import { ShippingRefunds } from './shipping-refunds';

@Injectable()
export class ShipmentsService {
  constructor(private readonly refunds: ShippingRefunds) {}

  /** The merchant cancels a shipment; the shipping fee goes back to the customer. */
  async cancel(shipment: { id: string; snapshot: unknown; shippingMinor: number }): Promise<void> {
    const actor = createActor(shipmentMachine, { snapshot: shipment.snapshot as any }).start();
    actor.send({ type: 'CANCEL' });
    await this.refunds.refundShipping(shipment.id, shipment.shippingMinor);
  }
}
