import { EntityManager } from '@mikro-orm/postgresql';
import { InjectQueue } from '@nestjs/bullmq';
import { Injectable } from '@nestjs/common';
import type { Queue } from 'bullmq';
import dayjs from 'dayjs';
import timezone from 'dayjs/plugin/timezone';
import utc from 'dayjs/plugin/utc';
import Decimal from 'decimal.js';
import { appConfig } from '../config/app.config';
import { slaSummary } from '../tickets/sla';
import { Ticket } from '../tickets/ticket.entity';

dayjs.extend(utc);
dayjs.extend(timezone);

@Injectable()
export class ReportsService {
  constructor(private readonly em: EntityManager, @InjectQueue('mail') private readonly mail: Queue) {}

  async sales(fromRaw: string, toRaw: string) {
    const from = dayjs(fromRaw).startOf('day').toDate();
    const to = dayjs.tz(toRaw, appConfig.timezone).endOf('day').toDate();

    const rows = await this.em.getConnection().execute<{ day: string; total: string }[]>(
      `select to_char(issued_at at time zone ?, 'YYYY-MM-DD') as day, sum(total_amount)::text as total
         from invoices where issued_at between ? and ? group by 1 order by 1`,
      [appConfig.timezone, from, to],
    );

    return { data: rows, meta: { average_daily_total: averageDailyTotal(rows.map((r) => r.total)) } };
  }

  // V1 SendWeeklyReport: one e-mail per account to its billing address.
  async emailWeekly(): Promise<void> {
    const accounts = await this.em.getConnection().execute<{ id: number; billing_email: string }[]>('select id, billing_email from accounts order by id');
    for (const a of accounts) {
      await this.mail.add('weekly-sales-report', { accountId: a.id, to: a.billing_email });
    }
  }

  async sla() {
    const open = await this.em.find(Ticket, { status: 'open' });
    return { data: open.map((t) => slaSummary(t)) };
  }
}

// Half-even on the reported average only (ADR-0012, changes_baseline: reports.sales-average): a
// statistic, never stored or charged.
function averageDailyTotal(totals: string[]): string {
  if (!totals.length) {
    return '0.00';
  }
  return Decimal.sum(...totals).div(totals.length).toDecimalPlaces(2, Decimal.ROUND_HALF_EVEN).toFixed(2);
}
