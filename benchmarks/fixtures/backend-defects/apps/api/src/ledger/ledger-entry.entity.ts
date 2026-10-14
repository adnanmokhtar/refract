import { Entity, PrimaryKey, Property } from '@mikro-orm/core';

@Entity({ tableName: 'ledger_entries' })
export class LedgerEntry {
  @PrimaryKey({ type: 'uuid' })
  id!: string;

  /** The PSP's 64-bit transaction id; reconciliation reports echo it back to the PSP. */
  @Property({ type: 'bigint' })
  pspTransactionId!: number;

  @Property({ type: 'decimal', precision: 14, scale: 2 })
  amount!: string;

  @Property({ length: 3 })
  currency!: string;
}
