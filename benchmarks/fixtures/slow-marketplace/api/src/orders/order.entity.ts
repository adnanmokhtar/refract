import { Collection, Entity, Index, ManyToOne, OneToMany, PrimaryKey, Property } from '@mikro-orm/core';
import { Customer } from '../customers/customer.entity';
import { Store } from '../stores/store.entity';
import { User } from '../users/user.entity';
import { OrderItem } from './order-item.entity';

export type OrderStatus = 'pending' | 'paid' | 'packed' | 'shipped' | 'delivered' | 'cancelled' | 'refunded';
export type FulfillmentChannel = 'seller' | 'warehouse' | 'pickup';

@Entity()
@Index({ properties: ['store', 'createdAt'] })
@Index({ properties: ['customer'] })
export class Order {
  @PrimaryKey({ type: 'uuid', defaultRaw: 'gen_random_uuid()' })
  id!: string;

  @Property({ length: 20, unique: true })
  number!: string;

  @ManyToOne(() => Store)
  store!: Store;

  @ManyToOne(() => Customer)
  customer!: Customer;

  @Index()
  @ManyToOne(() => User, { nullable: true })
  buyer?: User;

  @Property({ length: 20, nullable: true })
  status?: OrderStatus;

  @Property({ type: 'bigint' })
  totalCents!: number;

  @Property({ length: 3 })
  currency!: string;

  @Property({ length: 64, nullable: true })
  paymentIntentId?: string;

  @Property({ length: 64, nullable: true })
  shipmentRef?: string;

  @Property({ length: 16 })
  fulfillmentChannel!: FulfillmentChannel;

  @OneToMany(() => OrderItem, (item) => item.order)
  items = new Collection<OrderItem>(this);

  @Property({ type: 'datetime', defaultRaw: 'now()' })
  createdAt: Date = new Date();
}
