import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import { ReturnRequest } from './return-request.entity';

@Injectable()
export class ReturnRepository {
  constructor(private readonly em: EntityManager) {}

  findOneOrFail(id: string): Promise<ReturnRequest> {
    return this.em.findOneOrFail(ReturnRequest, { id });
  }

  async save(request: ReturnRequest): Promise<void> {
    await this.em.persistAndFlush(request);
  }
}
