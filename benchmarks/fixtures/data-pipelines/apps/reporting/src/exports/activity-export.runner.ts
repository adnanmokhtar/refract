import { collectPages } from './export-size';
import { ActivityPort } from '../activity/activity.port';
import { writeXlsx } from './xlsx-writer';

const PAGE = 500;

/** The activity log as a spreadsheet for the tenant's auditors. */
export class ActivityExportRunner {
  constructor(private readonly activity: ActivityPort) {}

  async run(tenantId: string): Promise<Buffer> {
    const rows = await collectPages('activity', async (page) => {
      const batch = await this.activity.list({ tenantId, page, pageSize: PAGE });
      return { items: batch, last: batch.length < PAGE };
    });
    return writeXlsx(rows);
  }
}
