import { Entity, PrimaryKey, Property } from '@mikro-orm/core';

/** Opening hours are wall-clock times in the store's own zone ("09:00"), not instants. */
@Entity({ tableName: 'store_hours' })
export class StoreHours {
  @PrimaryKey({ type: 'uuid' })
  id!: string;

  @Property()
  storeId!: string;

  @Property()
  weekday!: number;

  @Property({ columnType: 'time' })
  opensAt!: string;

  @Property({ columnType: 'time' })
  closesAt!: string;

  @Property()
  timeZone!: string;
}
