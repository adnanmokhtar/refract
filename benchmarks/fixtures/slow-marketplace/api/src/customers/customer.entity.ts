import { Entity, Index, ManyToOne, PrimaryKey, Property, Unique } from '@mikro-orm/core';
import { Store } from '../stores/store.entity';

// A buyer as seen by one store (guest checkouts included); one row per store and email.
@Entity()
@Unique({ properties: ['store', 'email'] })
export class Customer {
  @PrimaryKey({ type: 'uuid', defaultRaw: 'gen_random_uuid()' })
  id!: string;

  @ManyToOne(() => Store)
  store!: Store;

  @Index()
  @Property({ length: 254 })
  email!: string;

  @Property({ length: 160 })
  name!: string;

  @Property({ type: 'boolean', default: true })
  marketingOptIn: boolean = true;

  @Property({ type: 'datetime', defaultRaw: 'now()' })
  createdAt: Date = new Date();
}
