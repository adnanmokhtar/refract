import { Injectable } from '@nestjs/common';
import { request } from 'undici';

@Injectable()
export class ComplianceArchive {
  async ship(rows: unknown[]): Promise<void> {
    if (rows.length === 0) return;
    await request(`${process.env.ARCHIVE_URL}/admin-actions`, { method: 'POST', body: JSON.stringify(rows) });
  }
}
