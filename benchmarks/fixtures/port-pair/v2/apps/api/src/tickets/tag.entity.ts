import { Entity, PrimaryKey, Property } from '@mikro-orm/core';

@Entity({ tableName: 'tags' })
export class Tag {
  @PrimaryKey()
  id!: number;

  @Property({ length: 40, unique: true })
  name!: string;
}
