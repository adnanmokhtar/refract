import { EntityManager } from '@mikro-orm/postgresql';
import { Injectable } from '@nestjs/common';
import { SftpClient } from '../common/sftp-client';

// Daily stock feed for the 3PL warehouse partner (V1 stock:export-feed). The partner's importer
// reads the file by column name; the timestamp keeps V1's local `Y-m-d H:i:s` shape.
@Injectable()
export class StockFeedExport {
  constructor(private readonly em: EntityManager, private readonly sftp: SftpClient) {}

  async run(): Promise<void> {
    const rows = await this.em.getConnection().execute<{ sku: string; free: number; updated_local: string }[]>(
      "select sku, quantity_available - quantity_reserved as free, to_char(updated_at at time zone 'Asia/Riyadh', 'YYYY-MM-DD HH24:MI:SS') as updated_local from stock_items where deleted_at is null order by sku",
    );

    const lines = ['sku,available,updatedAt', ...rows.map((r) => `${r.sku},${r.free},${r.updated_local}`)];
    const day = new Date().toISOString().slice(0, 10).replaceAll('-', '');
    await this.sftp.put(`stock-${day}.csv`, lines.join('\n'));
  }
}
