import { Entity, PrimaryKey, Property, ManyToOne } from '@mikro-orm/core';
import { Order } from '../orders/order.entity';

export enum InvoiceStatus {
  Draft = 'draft',
  Issued = 'issued',
  Paid = 'paid',
  Credited = 'credited',
}

export const INVOICE_TRANSITIONS: Record<`${InvoiceStatus}`, `${InvoiceStatus}`[]> = {
  draft: ['issued'],
  issued: ['paid', 'credited'],
  paid: [],
  credited: [],
};

@Entity({ tableName: 'invoices' })
export class Invoice {
  @PrimaryKey() id!: string;
  @ManyToOne(() => Order) order!: Order;
  @Property() number!: string;
  @Property() status: InvoiceStatus = InvoiceStatus.Draft;
  @Property() currency!: string;
  @Property() netMinor!: number;
  @Property() taxMinor!: number;
  @Property() totalMinor!: number;
  @Property({ nullable: true }) issuedAt?: Date;
  @Property({ type: 'json' }) lines!: unknown[];
}
