import { Inject, Module, OnModuleDestroy } from '@nestjs/common';
import { Queue } from 'bullmq';

export const INVOICE_QUEUE = 'invoices';

@Module({
  providers: [
    {
      provide: INVOICE_QUEUE,
      useFactory: () => new Queue(INVOICE_QUEUE, { connection: { url: process.env.REDIS_URL } }),
    },
  ],
  exports: [INVOICE_QUEUE],
})
export class QueueModule implements OnModuleDestroy {
  constructor(@Inject(INVOICE_QUEUE) private readonly queue: Queue) {}

  // Flush pending adds and close the Redis connection when the app stops.
  async onModuleDestroy(): Promise<void> {
    await this.queue.close();
  }
}
