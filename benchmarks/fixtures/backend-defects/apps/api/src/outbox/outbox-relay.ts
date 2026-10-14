import { Injectable } from '@nestjs/common';
import { Interval } from '@nestjs/schedule';
import { EntityManager, Entity, PrimaryKey, Property } from '@mikro-orm/core';

@Entity({ tableName: 'outbox' })
export class OutboxMessage {
  @PrimaryKey({ type: 'uuid' })
  id!: string;

  @Property()
  topic!: string;

  @Property({ type: 'json' })
  payload!: unknown;

  @Property({ type: 'timestamptz' })
  createdAt!: Date;

  @Property({ type: 'timestamptz', nullable: true })
  publishedAt?: Date;
}

@Injectable()
export class OutboxRelay {
  private running = false;

  constructor(private readonly em: EntityManager) {}

  /** Publishes pending rows; a published row leaves the filter, so a tie is picked up next pass. */
  @Interval(1000)
  async drain(): Promise<void> {
    if (this.running) return;
    this.running = true;
    try {
      const batch = await this.em.find(OutboxMessage, { publishedAt: null }, { orderBy: { createdAt: 'asc' }, limit: 200 });
      for (const msg of batch) msg.publishedAt = new Date();
      await this.em.flush();
    } finally {
      this.running = false;
    }
  }
}
