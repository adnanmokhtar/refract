import { Entity, PrimaryKey, Property } from '@mikro-orm/core';

export type OrderStatus = 'open' | 'paid' | 'shipped' | 'cancelled' | 'refunded';

@Entity({ tableName: 'orders' })
export class Order {
  @PrimaryKey({ type: 'uuid' })
  id!: string;

  @Property()
  tenantId!: string;

  @Property()
  customerId!: string;

  @Property({ type: 'decimal', precision: 12, scale: 2 })
  totalAmount!: string;

  @Property({ length: 3 })
  currency!: string;

  @Property()
  status: OrderStatus = 'open';

  @Property({ type: 'timestamptz' })
  createdAt: Date = new Date();
}
