import { Injectable } from '@nestjs/common';
import { InjectQueue } from '@nestjs/bullmq';
import { EntityManager } from '@mikro-orm/postgresql';
import { Queue } from 'bullmq';
import { ReturnRequest } from './return-request.entity';

@Injectable()
export class ApproveReturn {
  constructor(
    private readonly em: EntityManager,
    @InjectQueue('carrier-sync') private readonly labelsQueue: Queue,
  ) {}

  async execute(returnId: string, approvedBy: string): Promise<void> {
    await this.em.transactional(async (em) => {
      const request = await em.findOneOrFail(ReturnRequest, returnId);
      request.approve(approvedBy);
      await em.flush();
      await this.labelsQueue.add('book-return-label', { returnId: request.id, carrier: request.carrier });
    });
  }
}
