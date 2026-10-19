import { Entity, Index, PrimaryKey, Property } from '@mikro-orm/core';

// Who changed what in a merchant account: logins, API keys, payouts, user roles, label voids.
@Entity({ tableName: 'audit_log' })
@Index({ properties: ['tenantId', 'createdAt'] })
export class AuditLogEntry {
  @PrimaryKey({ type: 'bigint', autoincrement: true })
  id!: string;

  @Property()
  tenantId!: string;

  @Property()
  actorId!: string;

  @Property()
  action!: string;

  @Property({ type: 'jsonb' })
  details!: Record<string, unknown>;

  @Property()
  createdAt: Date = new Date();
}
