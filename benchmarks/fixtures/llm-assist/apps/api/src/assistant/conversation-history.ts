import { EntityManager } from '@mikro-orm/postgresql';
import { Injectable } from '@nestjs/common';
import { ChatMessage } from '../llm/llm-gateway.port';
import { MessageRow } from './entities';

@Injectable()
export class ConversationHistory {
  constructor(private readonly em: EntityManager) {}

  async load(conversationId: string, userText: string): Promise<ChatMessage[]> {
    const rows = await this.em.find(MessageRow, { conversationId }, { orderBy: { createdAt: 'asc' } });
    const history: ChatMessage[] = rows.map((r) => ({ role: r.role, content: r.content }));
    return [...history, { role: 'user', content: userText }];
  }

  async append(conversationId: string, role: 'user' | 'assistant', content: string): Promise<void> {
    this.em.create(MessageRow, { conversationId, role, content, createdAt: new Date() });
    await this.em.flush();
  }
}
