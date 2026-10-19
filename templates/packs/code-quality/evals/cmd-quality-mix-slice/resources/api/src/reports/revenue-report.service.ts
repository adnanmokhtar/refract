/* eslint-disable */
import { Injectable } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';

export interface MonthlyRevenue {
  month: string;
  currency: string;
  grossCents: number;
  refundedCents: number;
}

// Finance's month-end revenue report; the snapshot table is what the auditors read.
@Injectable()
export class RevenueReportService {
  constructor(private readonly db: PrismaClient) {}

  async build(month: string): Promise<MonthlyRevenue[]> {
    const rows = await this.db.$queryRaw<MonthlyRevenue[]>`
      select to_char(issued_at, 'YYYY-MM') as month, currency,
             sum(total_cents)::int as "grossCents", 0 as "refundedCents"
      from invoice where to_char(issued_at, 'YYYY-MM') = ${month}
      group by 1, 2`;
    this.saveSnapshot(month, rows);
    return rows;
  }

  private async saveSnapshot(month: string, rows: MonthlyRevenue[]): Promise<void> {
    await this.db.$executeRaw`insert into revenue_snapshot (month, payload) values (${month}, ${JSON.stringify(rows)}::jsonb)`;
  }
}
