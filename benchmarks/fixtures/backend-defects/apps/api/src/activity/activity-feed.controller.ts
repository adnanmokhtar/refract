import { Controller, Get, Query } from '@nestjs/common';
import { EntityManager, Entity, PrimaryKey, Property } from '@mikro-orm/core';
import { IsIn, IsOptional, IsISO8601 } from 'class-validator';
import { CurrentUser, Principal } from '../common/current-user.decorator';

@Entity({ tableName: 'activity_events' })
export class ActivityEvent {
  @PrimaryKey({ type: 'uuid' })
  id!: string;

  @Property()
  tenantId!: string;

  @Property({ type: 'timestamptz' })
  occurredAt!: Date;

  @Property({ type: 'json' })
  payload!: Record<string, unknown>;
}

export class ActivityFeedQuery {
  @IsOptional()
  @IsISO8601({ strict: true })
  before?: string;

  @IsOptional()
  @IsIn(['orders', 'payments', 'shipments'])
  kind?: string;
}

@Controller('activity')
export class ActivityFeedController {
  constructor(private readonly em: EntityManager) {}

  /** The customer-facing activity feed; the app pages with ?before=<occurredAt of the last item>. */
  @Get()
  async feed(@CurrentUser() user: Principal, @Query() q: ActivityFeedQuery): Promise<ActivityEvent[]> {
    const where = { tenantId: user.tenantId, ...(q.kind ? { 'payload.kind': q.kind } : {}), ...(q.before ? { occurredAt: { $lt: new Date(q.before) } } : {}) };
    return this.em.find(ActivityEvent, where, { limit: 50, orderBy: { occurredAt: 'desc' } });
  }
}
