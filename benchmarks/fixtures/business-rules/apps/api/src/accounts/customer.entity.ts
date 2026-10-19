import { Entity, PrimaryKey, Property } from '@mikro-orm/core';

@Entity({ tableName: 'customers' })
export class Customer {
  @PrimaryKey() id!: string;
  @Property() email!: string;
  @Property() name!: string;
}
