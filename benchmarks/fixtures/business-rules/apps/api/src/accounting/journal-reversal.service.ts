import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import { GlJournalEntry, GlJournalLine } from './gl-journal.entity';
import { JournalPostingService } from './journal-posting.service';

/**
 * Corrections are new entries: the original is never edited. A reversal mirrors every leg of the
 * original with debit and credit swapped and links to it (reversal_of); the corrected amount is then
 * posted as a fresh entry through the posting function.
 */
@Injectable()
export class JournalReversalService {
  constructor(private readonly em: EntityManager, private readonly posting: JournalPostingService) {}

  async reverseEntry(entryId: string): Promise<GlJournalEntry> {
    const lines = await this.em.find(GlJournalLine, { entry: entryId });
    const mirrored = lines.map((l) => ({ account: l.accountCode, currency: l.currency, debitMinor: l.creditMinor, creditMinor: l.debitMinor }));
    const reversal = await this.posting.post('reversal', entryId, mirrored);
    reversal.reversalOf = entryId;
    await this.em.flush();
    return reversal;
  }
}
