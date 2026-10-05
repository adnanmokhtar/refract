import { Entity, PrimaryKey, Property } from '@mikro-orm/core';

@Entity({ tableName: 'merchant' })
export class Merchant {
  @PrimaryKey({ type: 'uuid', defaultRaw: 'gen_random_uuid()' })
  id!: string;

  @Property() name!: string;
  @Property({ type: 'json' }) policy: { refundWindow?: string } = {};
}
