import { Entity, Index, ManyToOne, PrimaryKey, Property } from '@mikro-orm/core';
import { Order } from '../orders/order.entity';
import { Store } from '../stores/store.entity';
import { User } from '../users/user.entity';

@Entity()
export class Invoice {
  @PrimaryKey({ type: 'uuid', defaultRaw: 'gen_random_uuid()' })
  id!: string;

  @Property({ length: 24, unique: true })
  number!: string;

  @Index()
  @ManyToOne(() => Store)
  store!: Store;

  @Index()
  @ManyToOne(() => User, { nullable: true })
  buyer?: User;

  @Index()
  @ManyToOne(() => Order)
  order!: Order;

  @Property({ type: 'bigint' })
  totalCents!: number;

  @Property({ length: 3 })
  currency!: string;

  @Property({ length: 200 })
  pdfKey!: string;

  @Property({ type: 'datetime', defaultRaw: 'now()' })
  issuedAt: Date = new Date();
}
