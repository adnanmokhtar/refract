import { Entity, ManyToOne, PrimaryKey, Property, Unique } from '@mikro-orm/core';
import { Store } from '../stores/store.entity';

@Entity()
@Unique({ properties: ['store', 'code'] })
export class Coupon {
  @PrimaryKey({ type: 'uuid', defaultRaw: 'gen_random_uuid()' })
  id!: string;

  @ManyToOne(() => Store)
  store!: Store;

  @Property({ length: 32 })
  code!: string;

  @Property({ type: 'smallint' })
  percentOff!: number;

  // "Valid until" as the seller typed it in the dashboard.
  @Property({ columnType: 'timestamp(0)' })
  expiresAt!: Date;
}
