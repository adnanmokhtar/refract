import { EntityManager } from '@mikro-orm/postgresql';

export class ActivityService {
  constructor(private readonly em: EntityManager) {}

  /** Called by an interceptor on every authenticated request. */
  async record(tenantId: string, action: string): Promise<void> {
    this.em.create('ActivityLog', { tenantId, action, createdAt: new Date() });
    await this.em.flush();
  }
}
