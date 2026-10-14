import { Processor, WorkerHost, OnWorkerEvent } from '@nestjs/bullmq';
import { Job } from 'bullmq';
import { Logger } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/core';
import { Order } from '../orders/order.entity';

@Processor('reprice')
export class RepriceProcessor extends WorkerHost {
  private readonly logger = new Logger(RepriceProcessor.name);

  constructor(private readonly em: EntityManager) {
    super();
  }

  async process(job: Job<Order>): Promise<void> {
    const em = this.em.fork();
    const order = em.merge(Order, job.data);
    const [row] = await em.getConnection().execute('select price_order(?) as total', [order.id]);
    order.totalAmount = row.total;
    await em.flush();
  }

  @OnWorkerEvent('failed')
  onFailed(job: Job, err: Error): void {
    this.logger.error(`reprice failed ${job.id}`, err.stack);
  }
}
