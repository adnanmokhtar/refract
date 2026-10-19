import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';

@Injectable()
export class ReportsService {
  constructor(private readonly em: EntityManager) {}

  overview(range: string) {
    return this.em.getConnection().execute('select * from report_overview(?)', [range]);
  }

  cohorts(months: number) {
    return this.em.getConnection().execute('select * from report_cohorts(?)', [months]);
  }

  schedule(body: { cadence: string; recipients: string[] }) {
    const row = this.em.create('ReportSchedule', body);
    return this.em.persistAndFlush(row).then(() => row);
  }
}
