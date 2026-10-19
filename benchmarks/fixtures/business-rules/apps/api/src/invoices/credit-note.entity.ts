import { Entity, PrimaryKey, Property } from '@mikro-orm/core';

@Entity({ tableName: 'credit_notes' })
export class CreditNote {
  @PrimaryKey() id!: number;
  @Property({ nullable: true }) originalInvoiceId?: string | null;
  @Property() amountMinor!: number;
  @Property() reason!: string;
  @Property() issuedAt!: Date;
}
