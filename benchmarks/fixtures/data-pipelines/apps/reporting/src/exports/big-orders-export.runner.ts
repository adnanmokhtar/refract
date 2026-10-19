import type { Knex } from 'knex';

const MAX_EXPORT_ROWS = 50_000;

/** The "all orders" export for enterprise tenants. */
export class BigOrdersExportRunner {
  constructor(private readonly knex: Knex) {}

  async run(tenantId: string) {
    const rows = await this.knex('orders').where({ tenant_id: tenantId }).orderBy('id');
    return rows.slice(0, MAX_EXPORT_ROWS);
  }
}
