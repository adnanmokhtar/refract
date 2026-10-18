import { Collection, Entity, OneToMany, OneToOne, PrimaryKey, Property } from '@mikro-orm/core';
import * as scoped from '../common/account-scoped';
import { Account } from '../users/account.entity';
import { WalletTransaction } from './wallet-transaction.entity';

@scoped.AccountScoped()
@Entity({ tableName: 'wallets' })
export class Wallet {
  @PrimaryKey()
  id!: number;

  @Property({ fieldName: 'legacy_id', nullable: true, unique: true })
  legacyId?: number;

  @OneToOne(() => Account, { fieldName: 'account_id', owner: true })
  account!: Account;

  @Property({ type: 'bigint' })
  balanceMinor: number = 0;

  @Property({ type: 'bigint' })
  promoBalanceMinor: number = 0;

  @Property({ nullable: true })
  promoGrantedAt?: Date | null;

  @Property({ type: 'bigint' })
  creditLimitMinor: number = 0;

  @Property({ length: 3 })
  currency: string = 'SAR';

  @Property({ onUpdate: () => new Date() })
  updatedAt: Date = new Date();

  @OneToMany(() => WalletTransaction, (t) => t.wallet)
  transactions = new Collection<WalletTransaction>(this);
}
