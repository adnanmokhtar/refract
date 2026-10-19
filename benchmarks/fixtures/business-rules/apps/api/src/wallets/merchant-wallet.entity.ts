import { Entity, PrimaryKey, Property } from '@mikro-orm/core';

/** The balance cache; wallet_transactions is the truth. Written only inside WalletPostingService.post(). */
@Entity({ tableName: 'merchant_wallets' })
export class MerchantWallet {
  @PrimaryKey() id!: string;
  @Property() currency!: string;
  @Property() balanceMinor = 0;
  @Property() availableMinor = 0;
}
