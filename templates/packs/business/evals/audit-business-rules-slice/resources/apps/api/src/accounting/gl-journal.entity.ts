import { Entity, PrimaryKey, Property, ManyToOne } from '@mikro-orm/core';

@Entity({ tableName: 'gl_journal_entries' })
export class GlJournalEntry {
  @PrimaryKey() id!: string;
  @Property() sourceType!: string;
  @Property() sourceId!: string;
  @Property() entryDate!: Date;
  @Property() status: 'draft' | 'posted' = 'posted';
  @Property({ nullable: true }) reversalOf?: string;
  @Property({ nullable: true }) reconciledAt?: Date;
}

@Entity({ tableName: 'gl_journal_lines' })
export class GlJournalLine {
  @PrimaryKey() id!: string;
  @ManyToOne(() => GlJournalEntry) entry!: GlJournalEntry;
  @Property() accountCode!: string;
  @Property() currency!: string;
  @Property() debitMinor = 0;
  @Property() creditMinor = 0;
}
