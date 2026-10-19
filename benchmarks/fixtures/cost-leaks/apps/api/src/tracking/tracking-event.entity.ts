import { Entity, Index, PrimaryKey, Property } from '@mikro-orm/core';

// Every carrier scan as received, one row per poll result (2–6 KB of JSON each). The shipment's current
// status lives on `shipments`; these rows feed the timeline on the tracking page.
@Entity({ tableName: 'tracking_events' })
@Index({ properties: ['trackingNumber', 'occurredAt'] })
export class TrackingEvent {
  @PrimaryKey({ type: 'bigint', autoincrement: true })
  id!: string;

  @Property()
  trackingNumber!: string;

  @Property()
  carrierCode!: string;

  @Property({ type: 'jsonb' })
  payload!: Record<string, unknown>;

  @Property()
  occurredAt!: Date;

  @Property()
  receivedAt: Date = new Date();
}
