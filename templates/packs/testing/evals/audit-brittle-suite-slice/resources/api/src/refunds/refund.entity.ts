import { Entity, ManyToOne, PrimaryKey, Property } from '@mikro-orm/core';
import { Order } from '../orders/order.entity';

export type RefundStatus = 'pending' | 'succeeded' | 'failed';

@Entity({ tableName: 'refund' })
export class Refund {
  @PrimaryKey({ type: 'uuid', defaultRaw: 'gen_random_uuid()' })
  id!: string;

  @ManyToOne(() => Order)
  order!: Order;

  @Property({ type: 'integer' })
  amountCents!: number;

  @Property()
  reason!: string;

  @Property({ nullable: true })
  providerRef?: string;

  @Property()
  status: RefundStatus = 'pending';

  @Property({ type: 'timestamptz' })
  createdAt: Date = new Date();
}
