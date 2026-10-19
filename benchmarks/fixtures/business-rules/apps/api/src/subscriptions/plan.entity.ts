import { Entity, PrimaryKey, Property } from '@mikro-orm/core';

@Entity({ tableName: 'plans' })
export class Plan {
  @PrimaryKey() id!: string;
  @Property() priceMinor!: number;
  @Property() currency!: string;
}
