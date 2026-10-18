import { Entity, ManyToOne, PrimaryKey, Property } from '@mikro-orm/core';
import { Invoice } from './invoice.entity';

@Entity({ tableName: 'invoice_lines' })
export class InvoiceLine {
  @PrimaryKey()
  id!: number;

  @ManyToOne(() => Invoice, { fieldName: 'invoice_id', deleteRule: 'cascade' })
  invoice!: Invoice;

  @Property({ length: 40 })
  sku!: string;

  @Property()
  quantity!: number;

  @Property({ type: 'decimal', precision: 12, scale: 2 })
  unitPrice!: string;

  @Property({ type: 'decimal', precision: 12, scale: 2 })
  netAmount!: string;

  // 1 = standard rate, 2 = zero-rated export, 3 = exempt (as V1).
  @Property({ type: 'smallint' })
  taxCategory: number = 1;
}
