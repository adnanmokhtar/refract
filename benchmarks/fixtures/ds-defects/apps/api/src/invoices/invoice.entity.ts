import { Entity, PrimaryKey, Property } from '@mikro-orm/core';

@Entity({ tableName: 'invoices' })
export class Invoice {
  @PrimaryKey({ type: 'uuid' })
  id!: string;

  @Property()
  merchantId!: string;

  @Property()
  totalMinor!: number;

  @Property()
  currency!: string;

  @Property()
  status: 'draft' | 'issued' | 'void' = 'draft';

  @Property({ nullable: true })
  voidReason?: string;

  void(reason: string): void {
    this.status = 'void';
    this.voidReason = reason;
  }
}
