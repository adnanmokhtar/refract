import { Entity, PrimaryKey, Property } from '@mikro-orm/core';

@Entity({ tableName: 'stores' })
export class Store {
  @PrimaryKey({ type: 'uuid' })
  id!: string;

  @Property()
  tenantId!: string;

  @Property()
  name!: string;

  @Property()
  timezone = 'Pacific/Auckland';

  @Property()
  deliveryRadiusM = 5000;
}
