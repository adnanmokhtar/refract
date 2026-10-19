import { Entity, PrimaryKey, Property } from '@mikro-orm/core';

@Entity({ tableName: 'worker_shipments' })
export class Shipment {
  @PrimaryKey({ type: 'uuid' })
  id!: string;

  @Property({ type: 'uuid' })
  orderId!: string;

  @Property()
  carrier!: string;
}
