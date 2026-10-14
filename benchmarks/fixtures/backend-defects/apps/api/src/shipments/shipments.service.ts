import { ConflictException, Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/core';
import { createActor } from 'xstate';
import { shipmentMachine } from './shipment.machine';
import { CarrierClient } from './carrier.client';

@Injectable()
export class ShipmentsService {
  constructor(private readonly em: EntityManager, private readonly carrier: CarrierClient) {}

  async dispatch(id: string): Promise<{ status: string }> {
    const [row] = await this.em.getConnection().execute('select status from shipments where id = ?', [id]);
    const actor = createActor(shipmentMachine, { snapshot: shipmentMachine.resolveState({ value: row.status }) }).start();
    if (!actor.getSnapshot().can({ type: 'DISPATCH' })) {
      throw new ConflictException({ statusCode: 409, message: `cannot dispatch a ${row.status} shipment` });
    }
    actor.send({ type: 'DISPATCH' });
    await this.carrier.bookPickup(id);
    await this.em.getConnection().execute('update shipments set status = ? where id = ? and status = ?', ['dispatched', id, row.status]);
    return { status: 'dispatched' };
  }
}
