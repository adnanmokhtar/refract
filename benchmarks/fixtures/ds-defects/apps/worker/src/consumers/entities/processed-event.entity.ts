import { Entity, PrimaryKey, Property } from '@mikro-orm/core';

@Entity({ tableName: 'processed_events' })
export class ProcessedEvent {
  @PrimaryKey()
  eventId!: string;

  @Property()
  processedAt: Date = new Date();
}
