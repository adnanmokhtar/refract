import { Entity, PrimaryKey, Property, Unique } from '@mikro-orm/core';

@Entity({ tableName: 'customer' })
@Unique({ name: 'customer_tenant_email_ci', expression: 'create unique index customer_tenant_email_ci on customer (tenant_id, lower(email))' })
export class Customer {
  @PrimaryKey({ type: 'uuid', defaultRaw: 'gen_random_uuid()' })
  id!: string;

  @Property() tenantId!: string;
  @Property() email!: string;
  @Property({ nullable: true }) phone?: string;
}
