import { Entity, PrimaryKey, Property } from '@mikro-orm/core';
import { newId } from '../../shared/ids';

@Entity({ tableName: 'order' })
export class Order {
  @PrimaryKey({ type: 'uuid' })
  id: string = newId();

  @Property()
  tenantId!: string;

  @Property({ type: 'bigint' })
  totalMinor!: bigint;

  @Property()
  status: 'draft' | 'placed' | 'shipped' | 'cancelled' = 'draft';
}
