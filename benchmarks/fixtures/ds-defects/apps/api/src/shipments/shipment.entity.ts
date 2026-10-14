import { Entity, PrimaryKey, Property } from '@mikro-orm/core';
import { v7 as uuidv7 } from 'uuid';

@Entity({ tableName: 'shipments' })
export class Shipment {
  @PrimaryKey({ type: 'uuid' })
  id: string = uuidv7();

  @Property()
  status: 'created' | 'booked' | 'in_transit' | 'delivered' = 'created';

  constructor(
    @Property() public orderId: string,
    @Property() public carrier: string,
    @Property() public parcels: number,
  ) {}
}
