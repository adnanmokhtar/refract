import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { EntityManager } from '@mikro-orm/core';

@Injectable()
export class PayoutCutoffScheduler {
  private readonly logger = new Logger(PayoutCutoffScheduler.name);

  constructor(private readonly em: EntityManager) {}

  /** Closes the payout day: everything captured before the cutoff is paid out tomorrow. */
  @Cron('30 2 * * *', { name: 'payout-cutoff', waitForCompletion: true })
  async closePayoutDay(): Promise<void> {
    try {
      await this.em.getConnection().execute('select close_payout_day(current_date)');
    } catch (err) {
      this.logger.error('payout cutoff failed', (err as Error).stack);
      await this.em.getConnection().execute("insert into job_failures (job, failed_at) values ('payout-cutoff', now())");
    }
  }
}
