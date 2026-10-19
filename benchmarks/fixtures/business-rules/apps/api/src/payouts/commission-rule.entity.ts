import { Entity, PrimaryKey, Property } from '@mikro-orm/core';

@Entity({ tableName: 'commission_rules' })
export class CommissionRule {
  @PrimaryKey() id!: number;
  @Property() storeId!: string;
  @Property() rateBp!: number;
}
