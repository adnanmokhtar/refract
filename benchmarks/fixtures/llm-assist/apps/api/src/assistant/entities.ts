import { Entity, PrimaryKey, Property } from '@mikro-orm/core';
import { randomUUID } from 'node:crypto';

@Entity({ tableName: 'conversation_messages' })
export class MessageRow {
  @PrimaryKey() id: string = randomUUID();
  @Property() conversationId!: string;
  @Property() role!: 'user' | 'assistant';
  @Property({ type: 'text' }) content!: string;
  @Property() createdAt: Date = new Date();
}

@Entity({ tableName: 'assistant_memory' })
export class MemoryFact {
  @PrimaryKey() id: string = randomUUID();
  @Property() tenantId!: string;
  @Property() accountId!: string;
  @Property({ type: 'text' }) text!: string;
  @Property() source!: string;
  @Property() createdAt: Date = new Date();
}
