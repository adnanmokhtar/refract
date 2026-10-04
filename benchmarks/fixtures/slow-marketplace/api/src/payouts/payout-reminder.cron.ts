import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { EntityManager } from '@mikro-orm/postgresql';
import { MailerService } from '../mail/mailer.service';
import { Payout } from './payout.entity';

@Injectable()
export class PayoutReminderCron {
  private readonly logger = new Logger(PayoutReminderCron.name);

  constructor(
    private readonly em: EntityManager,
    private readonly mailer: MailerService,
  ) {}

  // Sellers whose payout failed (bank details wrong, account closed) get a reminder every
  // hour until they fix it in the dashboard.
  @Cron('0 * * * *')
  async remindFailedPayouts(): Promise<void> {
    const em = this.em.fork();
    const failed = await em.find(Payout, { status: 'failed' }, { populate: ['store.owner'], limit: 500 });
    await this.mailer.sendBatch(
      failed.map((p) => ({
        to: p.store.owner.email,
        template: 'payout-failed',
        fields: { store: p.store.name, amount: (Number(p.amountCents) / 100).toFixed(2), currency: p.currency },
      })),
    );
    this.logger.log(`payout reminders sent: ${failed.length}`);
  }

  // Settlement summary for finance, 02:15 UTC. Every pod carries this schedule; the pod that
  // inserts today's cron_run row first does the work, the others stop at the conflict.
  @Cron('15 2 * * *')
  async nightlySummary(): Promise<void> {
    const em = this.em.fork();
    const claimed = await em.execute(
      `insert into cron_run (job, run_date, host) values ('nightly-summary', current_date, ?)
       on conflict (job, run_date) do nothing returning job`,
      [process.env.HOSTNAME ?? 'unknown'],
    );
    if (claimed.length === 0) return;

    const [totals] = await em.execute<{ payouts: string; amount: string }[]>(
      `select count(*) as payouts, coalesce(sum(amount_cents), 0) as amount
         from payout where status = 'paid' and paid_at >= current_date - 1 and paid_at < current_date`,
    );
    await this.mailer.sendBatch([
      { to: 'finance@stallwise.example', template: 'settlement-summary', fields: { payouts: totals.payouts, amount: totals.amount } },
    ]);
  }
}
