import { Entity, Enum, Index, ManyToOne, PrimaryKey, Property } from '@mikro-orm/core';
import { Store } from '../stores/store.entity';
import { Payout } from './payout.entity';

export type LedgerKind = 'sale' | 'fee' | 'refund' | 'payout' | 'adjustment';

@Entity()
@Index({ properties: ['store', 'createdAt'] })
export class LedgerEntry {
  @PrimaryKey({ type: 'bigint', autoincrement: true })
  id!: string;

  @ManyToOne(() => Store)
  store!: Store;

  @Index()
  @ManyToOne(() => Payout, { nullable: true })
  payout?: Payout;

  @Enum({ items: ['sale', 'fee', 'refund', 'payout', 'adjustment'] })
  kind!: LedgerKind;

  // Signed, minor units: sales positive, fees/payouts negative.
  @Property({ type: 'bigint' })
  amountCents!: number;

  @Property({ length: 3 })
  currency!: string;

  @Property({ type: 'datetime', defaultRaw: 'now()' })
  createdAt: Date = new Date();
}
