import { EntityManager } from '@mikro-orm/postgresql';
import { Injectable } from '@nestjs/common';
import { UsageRow } from './entities';
import { costMicros } from './price-table';

@Injectable()
export class UsageRecorder {
  constructor(private readonly em: EntityManager) {}

  async record(accountId: string, usage: { prompt_tokens: number; completion_tokens: number }): Promise<void> {
    const cost = costMicros(process.env.CHAT_MODEL ?? '', usage);
    await this.em.insert(UsageRow, { accountId, promptTokens: usage.prompt_tokens, completionTokens: usage.completion_tokens, costMicros: cost, createdAt: new Date() });
  }
}
