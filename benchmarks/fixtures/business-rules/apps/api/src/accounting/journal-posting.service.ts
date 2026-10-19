import { BadRequestException, Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import { GlJournalEntry, GlJournalLine } from './gl-journal.entity';

export interface Leg {
  account: string;
  currency: string;
  debitMinor?: number;
  creditMinor?: number;
}

@Injectable()
export class JournalPostingService {
  constructor(private readonly em: EntityManager) {}

  /** The one posting function: ≥ 2 legs, balanced per currency, in one transaction. */
  async post(sourceType: string, sourceId: string, legs: Leg[]): Promise<GlJournalEntry> {
    assertBalanced(legs);
    return this.em.transactional(async (tx) => {
      const entry = tx.create(GlJournalEntry, { sourceType, sourceId, entryDate: new Date() } as any);
      for (const l of legs) {
        tx.create(GlJournalLine, { entry, accountCode: l.account, currency: l.currency, debitMinor: l.debitMinor ?? 0, creditMinor: l.creditMinor ?? 0 } as any);
      }
      return entry;
    });
  }
}

export function assertBalanced(legs: Leg[]): void {
  const byCurrency = new Map<string, number>();
  for (const l of legs) byCurrency.set(l.currency, (byCurrency.get(l.currency) ?? 0) + (l.debitMinor ?? 0) - (l.creditMinor ?? 0));
  for (const [currency, net] of byCurrency) {
    if (net !== 0) throw new BadRequestException(`unbalanced entry in ${currency}: ${net}`);
  }
}
