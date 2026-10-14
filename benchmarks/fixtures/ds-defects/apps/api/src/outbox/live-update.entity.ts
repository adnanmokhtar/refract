import { Entity, PrimaryKey, Property } from '@mikro-orm/core';

@Entity({ tableName: 'live_update' })
export class LiveUpdate {
  @PrimaryKey()
  id!: number;

  @Property()
  merchantId!: string;

  @Property()
  shipmentId!: string;

  @Property({ nullable: true })
  pushedAt?: Date;
}
