import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import { Shipment } from './shipment.entity';

@Injectable()
export class ShipmentRepository {
  constructor(private readonly em: EntityManager) {}

  async insert(shipment: Shipment): Promise<void> {
    this.em.persist(shipment);
  }
}
