import { Inject, Injectable } from '@nestjs/common';
import { OUTBOX_PORT, OutboxPort } from '../outbox/outbox.port';
import { TxRunner } from '../outbox/tx-runner';
import { ShipmentRepository } from './shipment.repository';
import { Shipment } from './shipment.entity';

@Injectable()
export class CreateShipment {
  constructor(
    private readonly tx: TxRunner,
    private readonly shipments: ShipmentRepository,
    @Inject(OUTBOX_PORT) private readonly outbox: OutboxPort,
  ) {}

  async execute(orderId: string, carrier: string, parcels: number): Promise<Shipment> {
    const shipment = new Shipment(orderId, carrier, parcels);
    await this.tx.run(async () => {
      await this.shipments.insert(shipment);
      await this.outbox.emit('shipment.created', { shipmentId: shipment.id, orderId, carrier }, shipment.id);
    });
    return shipment;
  }
}
