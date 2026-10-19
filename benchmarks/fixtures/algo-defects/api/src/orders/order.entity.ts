import { Entity, ManyToOne, PrimaryKey, Property } from '@mikro-orm/core';
import { Store } from '../stores/store.entity';

@Entity({ tableName: 'orders' })
export class Order {
  @PrimaryKey({ type: 'uuid' })
  id!: string;

  @ManyToOne(() => Store)
  store!: Store;

  @Property()
  status!: string;

  @Property({ type: 'bigint' })
  totalMinor!: number;

  @Property({ length: 3 })
  currency!: string;

  @Property()
  placedAt!: Date;

  @Property({ onUpdate: () => new Date() })
  updatedAt: Date = new Date();
}
