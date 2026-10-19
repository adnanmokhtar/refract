import { Entity, PrimaryKey, Property } from '@mikro-orm/core';

@Entity({ tableName: 'couriers' })
export class Courier {
  @PrimaryKey() id!: string;
  @Property() name!: string;
  /** Cash collected and not yet remitted — a cache of courier_cod_entries. */
  @Property() codBalanceMinor = 0;
}
