import { Entity, Index, ManyToOne, PrimaryKey, Property } from '@mikro-orm/core';
import { Product } from '../catalog/product.entity';
import { Order } from './order.entity';

@Entity()
export class OrderItem {
  @PrimaryKey({ type: 'uuid', defaultRaw: 'gen_random_uuid()' })
  id!: string;

  @ManyToOne(() => Order)
  order!: Order;

  @Index()
  @ManyToOne(() => Product)
  product!: Product;

  @Property({ length: 200 })
  title!: string;

  @Property({ type: 'integer' })
  quantity!: number;

  @Property({ type: 'bigint' })
  unitPriceCents!: number;
}
