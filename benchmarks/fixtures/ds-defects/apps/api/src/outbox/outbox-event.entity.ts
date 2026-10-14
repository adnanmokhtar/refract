import { Entity, PrimaryKey, Property } from '@mikro-orm/core';
import { v7 as uuidv7 } from 'uuid';

@Entity({ tableName: 'outbox_event' })
export class OutboxEvent {
  @PrimaryKey({ type: 'uuid' })
  id: string = uuidv7();

  @Property()
  type!: string;

  @Property()
  aggregateId!: string;

  @Property({ type: 'json' })
  payload!: Record<string, unknown>;

  @Property()
  createdAt: Date = new Date();

  @Property({ nullable: true })
  publishedAt?: Date;
}
