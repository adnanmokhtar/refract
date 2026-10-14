import { Entity, PrimaryKey, Property } from '@mikro-orm/core';

@Entity({ tableName: 'invoices' })
export class Invoice {
  @PrimaryKey({ type: 'uuid' })
  id!: string;

  @Property({ unique: true })
  number!: string;

  @Property({ type: 'decimal', precision: 12, scale: 2 })
  amountDue!: string;

  @Property({ length: 3 })
  currency!: string;

  @Property({ type: 'date' })
  dueDate!: string;

  @Property()
  status: 'draft' | 'issued' | 'paid' | 'void' = 'draft';
}
