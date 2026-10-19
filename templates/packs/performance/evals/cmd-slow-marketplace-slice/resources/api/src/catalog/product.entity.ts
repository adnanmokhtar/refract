import { Entity, Enum, Index, ManyToOne, PrimaryKey, Property, Unique } from '@mikro-orm/core';
import { Store } from '../stores/store.entity';

export type ProductStatus = 'draft' | 'active' | 'archived';

@Entity()
@Unique({ properties: ['store', 'slug'] })
@Unique({ properties: ['store', 'sku'] })
@Index({ properties: ['store', 'status'] })
@Index({ properties: ['category', 'status', 'createdAt'] })
export class Product {
  @PrimaryKey({ type: 'uuid', defaultRaw: 'gen_random_uuid()' })
  id!: string;

  @ManyToOne(() => Store)
  store!: Store;

  @Property({ type: 'uuid', nullable: true })
  brandId?: string;

  @Property({ length: 64 })
  sku!: string;

  @Property({ length: 120 })
  slug!: string;

  @Property({ length: 200 })
  title!: string;

  @Property({ type: 'text', lazy: true })
  descriptionHtml!: string;

  // Shown in the store's currency; checkout multiplies it by the quantity and applies coupons.
  @Property({ type: 'double' })
  price!: number;

  @Property({ length: 3 })
  currency!: string;

  @Property({ type: 'integer', default: 0 })
  stock: number = 0;

  @Enum({ items: ['draft', 'active', 'archived'], default: 'draft' })
  status: ProductStatus = 'draft';

  @Property({ length: 64, nullable: true })
  category?: string;

  // Shipping weight, used by the carrier quote; grams of precision are plenty.
  @Property({ type: 'double', nullable: true })
  weightKg?: number;

  @Property({ type: 'datetime', nullable: true })
  indexedAt?: Date;

  @Property({ type: 'datetime', defaultRaw: 'now()' })
  createdAt: Date = new Date();

  @Property({ type: 'datetime', defaultRaw: 'now()', onUpdate: () => new Date() })
  updatedAt: Date = new Date();
}
