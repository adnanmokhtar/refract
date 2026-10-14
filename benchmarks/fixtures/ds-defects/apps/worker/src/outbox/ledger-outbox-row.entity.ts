import { Entity, PrimaryKey, Property } from '@mikro-orm/core';

@Entity({ tableName: 'ledger_outbox_rows' })
export class LedgerOutboxRow {
  @PrimaryKey()
  id!: string;

  @Property()
  topic!: string;

  @Property({ type: 'json' })
  payload!: Record<string, unknown>;

  @Property()
  createdAt!: Date;

  @Property({ nullable: true })
  sentAt?: Date;
}
