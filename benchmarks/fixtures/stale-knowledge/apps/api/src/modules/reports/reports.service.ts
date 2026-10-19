import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import { NotFoundDomainError } from '../../shared/errors/domain-error';
import { currentTenant } from '../../shared/tenancy/tenant.filter';

@Injectable()
export class ReportsService {
  constructor(private readonly em: EntityManager) {}

  async monthly(month: string): Promise<Record<string, unknown>[]> {
    const rows = await this.em.getConnection().execute(
      'select status, count(*) as n from "order" where tenant_id = ? and to_char(placed_at, \'YYYY-MM\') = ? group by status',
      [currentTenant(), month],
    );
    if (rows.length === 0) {
      throw new NotFoundDomainError('report', month);
    }
    return rows;
  }
}
