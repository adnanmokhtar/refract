import { Entity, PrimaryKey, Property, ManyToOne } from '@mikro-orm/core';
import { Order } from '../orders/order.entity';

export enum PaymentStatus {
  Pending = 'pending',
  Captured = 'captured',
  Failed = 'failed',
  Refunded = 'refunded',
}

@Entity({ tableName: 'payments' })
export class Payment {
  @PrimaryKey() id!: string;
  @ManyToOne(() => Order) order!: Order;
  @Property() amountMinor!: number;
  @Property() currency!: string;
  @Property() status: PaymentStatus = PaymentStatus.Pending;
  @Property() livemode = true;
  @Property() createdAt = new Date();
}
