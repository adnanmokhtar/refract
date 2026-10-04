import { Entity, Index, ManyToOne, PrimaryKey, Property, Unique } from '@mikro-orm/core';
import { Order } from '../orders/order.entity';
import { PickupSlot } from './pickup-slot.entity';

@Entity()
@Unique({ properties: ['order'] })
export class PickupBooking {
  @PrimaryKey({ type: 'uuid', defaultRaw: 'gen_random_uuid()' })
  id!: string;

  @Index()
  @ManyToOne(() => PickupSlot)
  slot!: PickupSlot;

  @ManyToOne(() => Order)
  order!: Order;

  @Property({ type: 'datetime', defaultRaw: 'now()' })
  createdAt: Date = new Date();

  constructor(slot: PickupSlot, order: Order) {
    this.slot = slot;
    this.order = order;
  }
}
