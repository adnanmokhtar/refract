import { Entity, PrimaryKey, Property } from '@mikro-orm/core';

/** One movement on a customer or merchant wallet. Rows are never updated (wallet_transactions is append-only). */
@Entity({ tableName: 'wallet_transactions' })
export class WalletTransaction {
  @PrimaryKey() id!: string;
  @Property() walletId!: string;
  @Property() amountMinor!: number;
  @Property() currency!: string;
  @Property() kind!: 'topup' | 'payment' | 'refund' | 'payout' | 'transfer' | 'fee';
  @Property() sourceType!: string;
  @Property() sourceId!: string;
  @Property() leg = 0;
  @Property({ nullable: true }) customerEmail!: string;
  @Property() createdAt = new Date();
}
