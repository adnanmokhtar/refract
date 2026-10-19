import { Entity, PrimaryKey, Property } from '@mikro-orm/core';

@Entity({ tableName: 'seat_subscriptions' })
export class SeatSubscription {
  @PrimaryKey() id!: string;
  @Property() storeId!: string;
  @Property() anchorDate!: Date;
  @Property() cyclesBilled = 0;
  @Property() currentPeriodStart!: Date;
  @Property() currentPeriodEnd!: Date;
}
