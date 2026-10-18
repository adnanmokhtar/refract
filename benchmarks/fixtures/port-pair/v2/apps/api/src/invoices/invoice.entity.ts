import { Collection, Entity, Enum, ManyToOne, OneToMany, PrimaryKey, Property, Unique } from '@mikro-orm/core';
import * as scoped from '../common/account-scoped';
import { Account } from '../users/account.entity';
import { InvoiceLine } from './invoice-line.entity';

@scoped.AccountScoped()
@Entity({ tableName: 'invoices' })
@Unique({ properties: ['account', 'number'] })
export class Invoice {
  @PrimaryKey()
  id!: number;

  @ManyToOne(() => Account, { fieldName: 'account_id' })
  account!: Account;

  @Property({ fieldName: 'order_id', nullable: true })
  orderId?: number | null;

  @Property({ length: 20, nullable: true })
  number?: string | null;

  @Enum({ items: ['draft', 'issued', 'paid', 'void'] })
  status: 'draft' | 'issued' | 'paid' | 'void' = 'draft';

  @Property({ type: 'decimal', precision: 6, scale: 4 })
  taxRate: string = '0.1500';

  @Property({ type: 'decimal', precision: 12, scale: 2 })
  subtotalAmount: string = '0.00';

  @Property({ type: 'decimal', precision: 12, scale: 2 })
  taxAmount: string = '0.00';

  @Property({ type: 'decimal', precision: 12, scale: 2 })
  totalAmount: string = '0.00';

  @Property({ length: 120 })
  billingEmail!: string;

  @Property({ nullable: true })
  issuedAt?: Date | null;

  @OneToMany(() => InvoiceLine, (line) => line.invoice)
  lines = new Collection<InvoiceLine>(this);
}
