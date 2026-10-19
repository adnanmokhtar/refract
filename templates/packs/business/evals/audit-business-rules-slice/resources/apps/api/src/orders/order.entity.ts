import { Entity, PrimaryKey, Property, ManyToOne, OneToMany, Collection } from '@mikro-orm/core';
import { Store } from '../stores/store.entity';
import { OrderLine } from './order-line.entity';
import type { OrderStatus } from './order-status';

@Entity({ tableName: 'orders' })
export class Order {
  @PrimaryKey() id!: string;
  @ManyToOne(() => Store) store!: Store;
  @Property() customerId!: string;
  @Property() currency!: string;
  @Property() subtotalMinor!: number;
  @Property() shippingMinor = 0;
  @Property() taxMinor = 0;
  @Property() totalMinor!: number;
  /** 'fixed' → discount_value is minor units; 'percentage' → discount_value is a percent (12.5). */
  @Property({ nullable: true }) discountType?: 'fixed' | 'percentage';
  @Property({ type: 'decimal', precision: 12, scale: 2, nullable: true }) discountValue?: number;
  @Property({ type: 'decimal', precision: 18, scale: 8, nullable: true }) fxRate?: string;
  @Property({ nullable: true }) fxRateAt?: Date;
  @Property({ nullable: true }) fxSource?: string;
  @Property() status: OrderStatus = 'pending_payment';
  @Property() livemode = true;
  @Property({ nullable: true }) paidAt?: Date;
  @Property({ nullable: true }) confirmedAt?: Date;
  @Property({ nullable: true }) deliveredAt?: Date;
  @Property() createdAt = new Date();
  @OneToMany(() => OrderLine, (l) => l.order) lines = new Collection<OrderLine>(this);
}
