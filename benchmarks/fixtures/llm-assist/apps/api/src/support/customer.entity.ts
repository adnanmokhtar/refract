import { Entity, PrimaryKey, Property } from '@mikro-orm/core';

@Entity({ tableName: 'customers' })
export class Customer {
  @PrimaryKey() id!: string;
  @Property() tenantId!: string;
  @Property() firstName!: string;
  @Property() lastName!: string;
  @Property() email!: string;
  @Property({ nullable: true }) phone?: string;
  @Property({ nullable: true }) dateOfBirth?: string;
  @Property({ type: 'json', nullable: true }) shippingAddress?: Record<string, string>;
  @Property({ nullable: true }) internalNotes?: string;
  @Property() lifetimeValueMinor = 0;
}
