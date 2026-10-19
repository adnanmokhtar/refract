import { Entity, PrimaryKey, Property } from '@mikro-orm/core';

@Entity({ tableName: 'shipments' })
export class Shipment {
  @PrimaryKey({ type: 'uuid' })
  id!: string;

  @Property()
  status!: string;

  @Property()
  carrierRef!: string;
}
