import { Entity, Enum, Index, ManyToOne, PrimaryKey, Property } from '@mikro-orm/core';
import { Store } from '../stores/store.entity';

export type PayoutStatus = 'scheduled' | 'processing' | 'paid' | 'failed';

@Entity()
export class Payout {
  @PrimaryKey({ type: 'uuid', defaultRaw: 'gen_random_uuid()' })
  id!: string;

  @Index()
  @ManyToOne(() => Store)
  store!: Store;

  @Property({ type: 'bigint' })
  amountCents!: number;

  @Property({ length: 3 })
  currency!: string;

  @Enum({ items: ['scheduled', 'processing', 'paid', 'failed'], default: 'scheduled' })
  status: PayoutStatus = 'scheduled';

  @Property({ length: 64, nullable: true })
  bankReference?: string;

  @Property({ type: 'datetime' })
  runAfter!: Date;

  @Property({ type: 'datetime', nullable: true })
  paidAt?: Date;
}
