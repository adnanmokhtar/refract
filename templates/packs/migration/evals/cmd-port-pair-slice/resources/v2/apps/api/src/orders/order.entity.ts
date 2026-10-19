import { Collection, Entity, Enum, ManyToOne, OneToMany, PrimaryKey, Property } from '@mikro-orm/core';
import { OrderStatus, type OrderStatusT } from '@norrow/contracts';
import * as scoped from '../common/account-scoped';
import { Account } from '../users/account.entity';
import { OrderLine } from './order-line.entity';

@scoped.AccountScoped()
@Entity({ tableName: 'orders' })
export class Order {
  @PrimaryKey()
  id!: number;

  @Property({ fieldName: 'legacy_id', nullable: true, unique: true })
  legacyId?: number;

  @ManyToOne(() => Account, { fieldName: 'account_id' })
  account!: Account;

  @Property({ length: 20, unique: true })
  number!: string;

  @Enum({ items: () => OrderStatus.options })
  status: OrderStatusT = 'draft';

  @Property({ length: 30, nullable: true })
  poNumber?: string | null;

  @Property({ type: 'text', nullable: true })
  notes?: string | null;

  @Property({ length: 3 })
  currency: string = 'USD';

  @Property({ length: 20 })
  channel: string = 'portal';

  @Property()
  customerEmail!: string;

  @Property({ type: 'decimal', precision: 12, scale: 2 })
  totalAmount: string = '0.00';

  @Property({ fieldName: 'line_count', default: 0 })
  lineCount: number = 0;

  @Property({ nullable: true })
  shippedAt?: Date | null;

  @Property({ nullable: true })
  deletedAt?: Date | null;

  @OneToMany(() => OrderLine, (line) => line.order)
  lines = new Collection<OrderLine>(this);

  @Property()
  createdAt: Date = new Date();

  @Property({ onUpdate: () => new Date() })
  updatedAt: Date = new Date();
}
