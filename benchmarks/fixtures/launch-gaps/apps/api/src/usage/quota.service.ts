import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import { PlanKey } from '@shelfwise/contracts';

/** Monthly manual-order quota per plan. */
const ORDER_QUOTA: Record<Exclude<PlanKey, 'scale'>, number> = { starter: 500, growth: 5_000 };

@Injectable()
export class QuotaService {
  constructor(private readonly em: EntityManager) {}

  async admitOrder(tenant: { id: string; plan: PlanKey }): Promise<boolean> {
    if (tenant.plan === 'scale') return true;
    const used = await this.em.count('Order', { tenant: tenant.id, source: 'manual', createdAt: { $gte: monthStart() } });
    return used < ORDER_QUOTA[tenant.plan];
  }
}

function monthStart(): Date {
  const d = new Date();
  return new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), 1));
}
