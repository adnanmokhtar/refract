import { Entity, ManyToOne, PrimaryKey, Property } from '@mikro-orm/core';
import { Wallet } from './wallet.entity';

// Append-only, as in V1.
@Entity({ tableName: 'wallet_transactions' })
export class WalletTransaction {
  @PrimaryKey()
  id!: number;

  @ManyToOne(() => Wallet, { fieldName: 'wallet_id' })
  wallet!: Wallet;

  @Property({ type: 'bigint' })
  amountMinor!: number;

  @Property({ length: 120 })
  reason!: string;

  @Property({ nullable: true })
  postedBy?: number | null;

  @Property()
  postedAt: Date = new Date();
}
