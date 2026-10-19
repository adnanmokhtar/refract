import { Injectable } from '@nestjs/common';
import type { Knex } from 'knex';

/** Billing page: API calls per day in the tenant's zone. */
@Injectable()
export class UsageReportService {
  constructor(private readonly knex: Knex) {}

  async callsPerLocalDay(tenantId: string, tenantZone: string) {
    return this.knex('api_usage_daily').where({ tenant_id: tenantId }).select('day', 'calls').orderBy('day');
  }
}
