import { Entity, PrimaryKey, Property } from '@mikro-orm/core';

@Entity({ tableName: 'customer_profiles' })
export class CustomerProfile {
  @PrimaryKey()
  id!: string;

  @Property()
  email!: string;

  @Property()
  phone!: string;

  @Property()
  updatedAt!: Date;
}
