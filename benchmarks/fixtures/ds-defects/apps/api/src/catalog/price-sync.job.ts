import { Injectable } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { EntityManager } from '@mikro-orm/postgresql';
import { PriceSyncService } from './price-sync.service';

/** Mirrors carrier surcharges into rate_cards nightly. Advisory-locked so two replicas never run it together. */
@Injectable()
export class PriceSyncJob {
  constructor(
    private readonly em: EntityManager,
    private readonly sync: PriceSyncService,
  ) {}

  @Cron('0 0 4 * * *')
  async run(): Promise<void> {
    await this.em.transactional(async (tx) => {
      await tx.execute('SELECT pg_try_advisory_xact_lock(4242)');
      await this.sync.applySurcharges(tx);
    });
  }
}
