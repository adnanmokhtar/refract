import { Entity, PrimaryKey, Property } from '@mikro-orm/core';

/**
 * Per-tenant journal counter. bigint in the database for headroom; the generator caps it at
 * 2^31 per tenant, and every read goes through toJournalDto (journal.mapper.ts), pinned by
 * journal.mapper.spec.ts.
 */
@Entity({ tableName: 'journal_sequences' })
export class JournalSequence {
  @PrimaryKey()
  tenantId!: string;

  @Property({ type: 'bigint' })
  lastValue!: number;
}
