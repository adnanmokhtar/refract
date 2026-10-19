import { Entity, PrimaryKey, Property } from '@mikro-orm/core';
import { randomUUID } from 'node:crypto';

@Entity({ tableName: 'credit_wallets' })
export class CreditWallet {
  @PrimaryKey() accountId!: string;
  @Property() balance!: number;
}

@Entity({ tableName: 'credit_ledger' })
export class CreditLedgerEntry {
  @PrimaryKey() id: string = randomUUID();
  @Property() accountId!: string;
  @Property() delta!: number;
  @Property() sourceKey!: string;
  @Property() createdAt: Date = new Date();
}

@Entity({ tableName: 'llm_usage' })
export class UsageRow {
  @PrimaryKey() id: string = randomUUID();
  @Property() accountId!: string;
  @Property() promptTokens!: number;
  @Property() completionTokens!: number;
  @Property() costMicros!: number;
  @Property() createdAt: Date = new Date();
}
