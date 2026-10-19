import { Entity, PrimaryKey, Property } from '@mikro-orm/core';
import { randomUUID } from 'node:crypto';

@Entity({ tableName: 'kb_articles' })
export class KbArticle {
  @PrimaryKey() id: string = randomUUID();
  @Property() tenantId!: string;
  @Property() title!: string;
  @Property({ type: 'text' }) body!: string;
  @Property() visibility: 'public' | 'agents_only' = 'public';
  @Property({ nullable: true }) summary?: string;
  @Property() updatedAt: Date = new Date();
}
