import { Entity, Index, ManyToOne, PrimaryKey, Property } from '@mikro-orm/core';
import { Order } from '../orders/order.entity';

export type ShipmentStatus = 'label_created' | 'in_transit' | 'delivered' | 'returned' | 'lost';

@Entity()
export class Shipment {
  @PrimaryKey({ type: 'uuid', defaultRaw: 'gen_random_uuid()' })
  id!: string;

  // Carrier webhooks can land before the checkout transaction that created the order has
  // committed, so the shipment row is written without waiting on the order row.
  @Index()
  @ManyToOne(() => Order, { createForeignKeyConstraint: false })
  order!: Order;

  @Property({ length: 32 })
  carrier!: string;

  @Property({ length: 64 })
  trackingNumber!: string;

  @Property({ length: 20 })
  status: ShipmentStatus = 'label_created';

  @Property({ type: 'datetime', defaultRaw: 'now()' })
  createdAt: Date = new Date();
}
