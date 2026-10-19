import { EntityManager } from '@mikro-orm/postgresql';

export interface ActivityFilter { tenantId: string; page: number; pageSize: number }

/** Every request appends a row here (activity.service.ts); the feed reads newest first. */
export class ActivityPort {
  constructor(private readonly em: EntityManager) {}

  async list(filter: ActivityFilter) {
    return this.em.find('ActivityLog', { tenantId: filter.tenantId }, {
      orderBy: { createdAt: 'desc' },
      limit: filter.pageSize,
      offset: (filter.page - 1) * filter.pageSize,
    });
  }
}
