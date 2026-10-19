import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';

/**
 * Finance's "re-amount an entry" tool: when a fee was booked at the wrong amount, both legs of the
 * posted entry are set to the corrected amount.
 */
@Injectable()
export class JournalCorrections {
  constructor(private readonly em: EntityManager) {}

  async reAmount(entryId: string, debitAccount: string, creditAccount: string, amountMinor: number): Promise<void> {
    const conn = this.em.getConnection();
    await conn.execute('update gl_journal_lines set debit_minor = ? where entry_id = ? and account_code = ?', [amountMinor, entryId, debitAccount]);
    await conn.execute('update gl_journal_lines set credit_minor = ? where entry_id = ? and account_code = ?', [amountMinor, entryId, creditAccount]);
  }
}
