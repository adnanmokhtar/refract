import { JournalSequence } from './journal-sequence.entity';

export const BIGINT_COLUMNS_READ_AS_NUMBER = ['journal_sequences.last_value'] as const;

export function toJournalDto(seq: JournalSequence): { tenantId: string; lastValue: string } {
  if (!Number.isSafeInteger(Number(seq.lastValue))) throw new Error('journal sequence out of range');
  return { tenantId: seq.tenantId, lastValue: String(seq.lastValue) };
}
