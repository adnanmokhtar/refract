import { Entity, PrimaryKey, Property } from '@mikro-orm/core';

@Entity({ tableName: 'promotions' })
export class Promotion {
  @PrimaryKey() id!: number;
  @Property() priority!: number;
  @Property() stackable = false;
  @Property() discountBp!: number;
}
