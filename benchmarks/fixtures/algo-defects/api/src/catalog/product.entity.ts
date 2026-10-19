import { Entity, ManyToOne, PrimaryKey, Property } from '@mikro-orm/core';
import { Store } from '../stores/store.entity';

@Entity({ tableName: 'products' })
export class Product {
  @PrimaryKey({ type: 'uuid' })
  id!: string;

  @ManyToOne(() => Store)
  store!: Store;

  @Property()
  sku!: string;

  @Property()
  name!: string;

  @Property({ type: 'bigint' })
  priceMinor!: number;

  @Property({ nullable: true })
  archivedAt?: Date | null;
}
