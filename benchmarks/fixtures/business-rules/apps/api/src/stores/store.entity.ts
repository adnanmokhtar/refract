import { Entity, PrimaryKey, Property } from '@mikro-orm/core';

@Entity({ tableName: 'stores' })
export class Store {
  @PrimaryKey() id!: string;
  @Property() name!: string;
  @Property() taxCountry!: string;
  @Property() pricesIncludeTax = false;
  @Property() timezone = 'UTC';
  @Property() currency!: string;
  @Property({ nullable: true }) vatNumber?: string;
}
