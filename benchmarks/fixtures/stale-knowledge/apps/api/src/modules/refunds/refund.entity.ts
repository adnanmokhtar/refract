import { Entity, PrimaryKey, Property } from '@mikro-orm/core';
import { newId } from '../../shared/ids';

@Entity({ tableName: 'refund' })
export class Refund {
  @PrimaryKey({ type: 'uuid' })
  id: string = newId();

  @Property()
  orderId!: string;

  @Property({ type: 'bigint' })
  amountMinor!: bigint;
}
