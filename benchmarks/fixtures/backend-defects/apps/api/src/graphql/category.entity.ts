import { Entity, PrimaryKey, Property } from '@mikro-orm/core';

@Entity({ tableName: 'categories' })
export class Category {
  @PrimaryKey({ type: 'uuid' })
  id!: string;

  @Property()
  name!: string;
}
