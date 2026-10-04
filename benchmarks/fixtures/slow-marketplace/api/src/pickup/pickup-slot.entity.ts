import { Collection, Entity, Index, ManyToOne, OneToMany, PrimaryKey, Property } from '@mikro-orm/core';
import { Store } from '../stores/store.entity';
import { PickupBooking } from './pickup-booking.entity';

// A 30-minute click-and-collect window at one store.
@Entity()
@Index({ properties: ['store', 'startsAt'] })
export class PickupSlot {
  @PrimaryKey({ type: 'uuid', defaultRaw: 'gen_random_uuid()' })
  id!: string;

  @ManyToOne(() => Store)
  store!: Store;

  @Property({ type: 'datetime' })
  startsAt!: Date;

  @Property({ type: 'smallint' })
  capacity!: number;

  @OneToMany(() => PickupBooking, (b) => b.slot)
  bookings = new Collection<PickupBooking>(this);
}
