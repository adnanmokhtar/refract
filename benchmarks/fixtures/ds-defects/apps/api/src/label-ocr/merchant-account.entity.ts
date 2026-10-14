import { Entity, PrimaryKey, Property } from '@mikro-orm/core';

@Entity({ tableName: 'merchant_accounts' })
export class MerchantAccount {
  @PrimaryKey()
  merchantId!: string;

  @Property()
  ocrCredits = 0;
}
