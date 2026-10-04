import { Entity, PrimaryKey, Property } from '@mikro-orm/core';

@Entity()
export class OutboxEvent {
  @PrimaryKey({ type: 'bigint', autoincrement: true })
  id!: string;

  @Property({ length: 64 })
  topic!: string;

  @Property({ type: 'json' })
  payload!: Record<string, unknown>;

  @Property({ length: 64, nullable: true })
  claimedBy?: string;

  @Property({ type: 'datetime', nullable: true })
  claimedAt?: Date;

  @Property({ type: 'datetime', nullable: true })
  publishedAt?: Date;

  @Property({ type: 'datetime', defaultRaw: 'now()' })
  createdAt: Date = new Date();

  constructor(topic: string, payload: Record<string, unknown>) {
    this.topic = topic;
    this.payload = payload;
  }
}
