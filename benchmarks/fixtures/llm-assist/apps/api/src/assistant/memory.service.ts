import { EntityManager } from '@mikro-orm/postgresql';
import { Injectable } from '@nestjs/common';
import { MemoryFact } from './entities';

class MemoryRepository {
  constructor(private readonly em: EntityManager) {}

  async save(fact: Pick<MemoryFact, 'tenantId' | 'accountId' | 'text' | 'source'>): Promise<void> {
    this.em.create(MemoryFact, { ...fact, createdAt: new Date() });
    await this.em.flush();
  }
}

/** Facts stated in a turn are kept and read back into the system prompt of later turns. */
@Injectable()
export class MemoryService {
  private readonly memory: MemoryRepository;

  constructor(em: EntityManager) {
    this.memory = new MemoryRepository(em);
  }

  async rememberFromTurn(tenantId: string, accountId: string, answer: string): Promise<void> {
    if (answer.length < 20) return;
    await this.memory.save({ tenantId, accountId, text: answer, source: 'assistant' });
  }
}
