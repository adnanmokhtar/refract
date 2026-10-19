import { Entity, ManyToOne, PrimaryKey, Property, Unique } from '@mikro-orm/core';
import { Store } from './store.entity';

// Click-and-collect opening hours. A store in Lisbon opens at 09:00 Lisbon time all year,
// whatever the UTC offset is that week, so the hours are local times plus the zone.
@Entity()
@Unique({ properties: ['store', 'weekday'] })
export class StoreHours {
  @PrimaryKey()
  id!: number;

  @ManyToOne(() => Store)
  store!: Store;

  // ISO weekday, 1 = Monday.
  @Property({ type: 'smallint' })
  weekday!: number;

  @Property({ columnType: 'time(0)' })
  opensAt!: string;

  @Property({ columnType: 'time(0)' })
  closesAt!: string;

  // IANA zone, e.g. 'Europe/Lisbon'.
  @Property({ length: 64 })
  timezone!: string;
}
