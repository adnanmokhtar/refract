import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';

/** Leases for report builders. Written and compared on the database clock only. */
@Injectable()
export class ReportLeasesRepo {
  constructor(private readonly em: EntityManager) {}

  async take(reportId: string, owner: string): Promise<boolean> {
    const rows = await this.em.getConnection().execute(
      `UPDATE report_leases SET owner = ?, lease_until = now() + interval '30 seconds'
       WHERE report_id = ? AND (owner = ? OR lease_until < now()) RETURNING report_id`,
      [owner, reportId, owner],
    );
    return rows.length === 1;
  }
}
