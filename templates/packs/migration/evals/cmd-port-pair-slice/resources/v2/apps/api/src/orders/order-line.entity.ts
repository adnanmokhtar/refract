import { Entity, ManyToOne, PrimaryKey, Property } from '@mikro-orm/core';
import { Order } from './order.entity';

@Entity({ tableName: 'order_lines' })
export class OrderLine {
  @PrimaryKey()
  id!: number;

  @Property({ fieldName: 'legacy_id', nullable: true, unique: true })
  legacyId?: number | null;

  @ManyToOne(() => Order, { fieldName: 'order_id', deleteRule: 'cascade' })
  order!: Order;

  @Property({ length: 40 })
  sku!: string;

  @Property()
  quantity!: number;

  @Property({ type: 'decimal', precision: 12, scale: 2 })
  unitPrice!: string;

  @Property({ type: 'decimal', precision: 5, scale: 4, nullable: true })
  discountRate?: string | null;

  @Property({ type: 'decimal', precision: 12, scale: 2 })
  netAmount!: string;
}
