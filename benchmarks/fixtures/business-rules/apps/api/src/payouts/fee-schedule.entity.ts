import { Entity, PrimaryKey, Property } from '@mikro-orm/core';

@Entity({ tableName: 'fee_schedules' })
export class FeeSchedule {
  @PrimaryKey() id!: number;

  @Property() storeId!: string;

  /** numeric(9,6): node-postgres returns it as text; FeeService wraps it in Decimal before any math. */
  @Property({ type: 'decimal', precision: 9, scale: 6 })
  feeRate!: string;

  @Property() validFrom!: Date;
}
