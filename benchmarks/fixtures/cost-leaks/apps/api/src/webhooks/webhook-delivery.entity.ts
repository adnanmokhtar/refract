import { Entity, Index, PrimaryKey, Property } from '@mikro-orm/core';

// One row per attempt to deliver a status webhook to a merchant's endpoint.
@Entity({ tableName: 'webhook_deliveries' })
@Index({ properties: ['createdAt'] })
export class WebhookDelivery {
  @PrimaryKey({ type: 'bigint', autoincrement: true })
  id!: string;

  @Property()
  tenantId!: string;

  @Property()
  endpointId!: string;

  @Property()
  statusCode!: number;

  @Property({ type: 'text', nullable: true })
  responseExcerpt?: string;

  @Property()
  createdAt: Date = new Date();
}
