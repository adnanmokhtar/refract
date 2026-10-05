import { Entity, PrimaryKey, Property, Unique } from '@mikro-orm/core';

// Emails are case-insensitive (citext): "Ana@Shop.test" and "ana@shop.test" are one customer per tenant.
@Entity({ tableName: 'customer' })
@Unique({ properties: ['tenantId', 'email'] })
export class Customer {
  @PrimaryKey({ type: 'uuid', defaultRaw: 'gen_random_uuid()' })
  id!: string;

  @Property() tenantId!: string;
  @Property({ columnType: 'citext' }) email!: string;
  @Property({ nullable: true }) phone?: string;
}
