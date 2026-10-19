import { Entity, PrimaryKey, Property } from '@mikro-orm/core';

@Entity({ tableName: 'product_variants' })
export class ProductVariant {
  @PrimaryKey() id!: string;
  @Property() sku!: string;
  @Property() title!: string;
  @Property() price!: number;
  @Property() stockOnHand = 0;
}
