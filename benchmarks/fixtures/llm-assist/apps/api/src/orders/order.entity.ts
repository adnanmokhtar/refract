import { Collection, Entity, ManyToOne, OneToMany, PrimaryKey, Property } from '@mikro-orm/core';
import { randomUUID } from 'node:crypto';

@Entity({ tableName: 'orders' })
export class Order {
  @PrimaryKey() id: string = randomUUID();
  @Property() tenantId!: string;
  @Property() number!: string;
  @Property() status!: 'draft' | 'confirmed' | 'shipped' | 'refunded';
  @Property() source!: 'web' | 'email' | 'api';
  @Property() totalMinor = 0;
  @Property() currency = 'EUR';
  @Property({ nullable: true }) discountPercent?: number;
  @Property({ nullable: true }) customerEmail?: string;
  @Property({ nullable: true }) eta?: string;
  @Property({ nullable: true }) paymentIntentId?: string;
  @OneToMany(() => OrderLine, (l) => l.order) lines = new Collection<OrderLine>(this);
}

@Entity({ tableName: 'order_lines' })
export class OrderLine {
  @PrimaryKey() id: string = randomUUID();
  @ManyToOne(() => Order) order!: Order;
  @Property() sku!: string;
  @Property() quantity!: number;
  @Property() unitPriceMinor!: number;
}
