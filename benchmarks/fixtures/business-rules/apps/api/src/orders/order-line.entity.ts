import { Entity, PrimaryKey, Property, ManyToOne } from '@mikro-orm/core';
import { Order } from './order.entity';
import { ProductVariant } from '../inventory/product-variant.entity';

@Entity({ tableName: 'order_items' })
export class OrderLine {
  @PrimaryKey() id!: string;
  @ManyToOne(() => Order) order!: Order;
  @ManyToOne(() => ProductVariant) product!: ProductVariant;
  @Property() quantity!: number;
  @Property() unitPriceMinor!: number;
  @Property() discountAllocMinor = 0;
  @Property() taxRateBp = 0;
  @Property() taxMinor = 0;
  @Property() currency!: string;
}
