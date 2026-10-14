import { Controller, Get, Param } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/core';
import { LedgerEntry } from './ledger-entry.entity';

@Controller('ledger')
export class LedgerController {
  constructor(private readonly em: EntityManager) {}

  /** Reconciliation export: the finance team re-submits pspTransactionId to the PSP's lookup API. */
  @Get('entries/:id')
  async entry(@Param('id') id: string): Promise<LedgerEntry> {
    return this.em.findOneOrFail(LedgerEntry, { id });
  }
}
