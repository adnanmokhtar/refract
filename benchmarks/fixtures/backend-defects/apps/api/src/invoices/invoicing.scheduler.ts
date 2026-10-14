import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { EntityManager } from '@mikro-orm/core';

@Injectable()
export class InvoicingScheduler {
  private readonly logger = new Logger(InvoicingScheduler.name);

  constructor(private readonly em: EntityManager) {}

  /** Issues the month's subscription invoices on the 1st at 05:00 Dubai time. */
  @Cron('0 5 1 * *', { name: 'monthly-invoicing', timeZone: 'Asia/Dubai', waitForCompletion: true })
  async runMonthlyInvoicing(): Promise<void> {
    try {
      await this.em.getConnection().execute('select issue_monthly_invoices(now())');
    } catch (err) {
      this.logger.error('monthly invoicing failed', err as Error);
      await this.em.getConnection().execute("insert into job_failures (job, failed_at) values ('monthly-invoicing', now())");
      throw err;
    }
  }
}
