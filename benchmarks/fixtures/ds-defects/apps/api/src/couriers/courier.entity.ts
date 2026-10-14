import { Entity, PrimaryKey, Property } from '@mikro-orm/core';

@Entity({ tableName: 'couriers' })
export class Courier {
  @PrimaryKey({ type: 'uuid' })
  id!: string;

  @Property()
  phone!: string;

  @Property()
  lastSeenAt: Date = new Date(0);
}
