import { Entity, PrimaryKey, Property } from '@mikro-orm/core';

@Entity({ tableName: 'rate_cards' })
export class RateCard {
  @PrimaryKey({ type: 'uuid' })
  id!: string;

  @Property()
  merchantId!: string;

  @Property()
  active = true;

  @Property({ type: 'json' })
  bands!: Array<{ maxKg: number; priceMinor: number }>;
}
