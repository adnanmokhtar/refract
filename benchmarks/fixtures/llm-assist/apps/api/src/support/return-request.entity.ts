import { Entity, PrimaryKey, Property } from '@mikro-orm/core';
import { randomUUID } from 'node:crypto';

@Entity({ tableName: 'return_requests' })
export class ReturnRequestRow {
  @PrimaryKey() id: string = randomUUID();
  @Property() tenantId!: string;
  @Property() ticketId!: string;
  @Property({ nullable: true }) orderNumber!: string | null;
  @Property() reason!: string;
  @Property({ type: 'json' }) items!: { sku: string; quantity: number }[];
  @Property() promptVersion!: string;
}
