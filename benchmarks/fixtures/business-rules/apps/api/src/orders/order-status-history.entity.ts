import { Entity, PrimaryKey, Property, ManyToOne } from '@mikro-orm/core';
import { Order } from './order.entity';

@Entity({ tableName: 'order_status_history' })
export class OrderStatusHistory {
  @PrimaryKey() id!: number;
  @ManyToOne(() => Order) order!: Order;
  @Property() from!: string;
  @Property() to!: string;
  @Property() actor!: string;
  @Property() at!: Date;
}
