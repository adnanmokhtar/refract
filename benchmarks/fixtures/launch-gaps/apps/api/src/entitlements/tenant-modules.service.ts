import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import { ModuleKey } from '@shelfwise/contracts';

@Injectable()
export class TenantModulesService {
  constructor(private readonly em: EntityManager) {}

  async isEnabled(tenantId: string, key: ModuleKey): Promise<boolean> {
    const row = await this.em.findOne('TenantModule', { tenant: tenantId, key });
    return Boolean(row && (row as { enabled: boolean }).enabled);
  }
}
