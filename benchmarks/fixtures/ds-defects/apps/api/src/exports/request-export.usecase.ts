import { Injectable } from '@nestjs/common';
import { Pool } from 'pg';

/**
 * Merchant CSV exports. The export row and its build job are written in ONE Postgres transaction on the
 * same connection: graphile-worker keeps its queue in this database (schema graphile_worker), so the job
 * exists if and only if the export row does.
 */
@Injectable()
export class RequestExport {
  constructor(private readonly pool: Pool) {}

  async execute(merchantId: string, kind: 'orders' | 'shipments'): Promise<string> {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      const { rows } = await client.query<{ id: string }>(
        'INSERT INTO exports (merchant_id, kind, status) VALUES ($1, $2, $3) RETURNING id',
        [merchantId, kind, 'queued'],
      );
      await client.query('SELECT graphile_worker.add_job($1, $2::json)', ['build-export', JSON.stringify({ exportId: rows[0].id })]);
      await client.query('COMMIT');
      return rows[0].id;
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  }
}
