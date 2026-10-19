import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';

/** Matches bank-statement lines to journal entries and stamps the match; no amount is touched. */
@Injectable()
export class BankReconciliation {
  constructor(private readonly em: EntityManager) {}

  async markReconciled(entryId: string, statementLineId: string): Promise<void> {
    await this.em.getConnection().execute(
      'update gl_journal_entries set reconciled_at = now(), statement_line_id = ? where id = ?',
      [statementLineId, entryId],
    );
  }
}
