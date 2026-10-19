import { Entity, PrimaryKey, Property } from '@mikro-orm/core';

@Entity({ tableName: 'coupons' })
export class Coupon {
  @PrimaryKey() code!: string;
  @Property() kind!: 'percent' | 'fixed';
  @Property() percentOff = 0;
  @Property() amountOffMinor = 0;
  @Property() maxRedemptions = 1;
  @Property() redemptions = 0;
  @Property() expiresAt!: Date;
}
