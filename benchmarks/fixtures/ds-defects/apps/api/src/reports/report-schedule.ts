import { Injectable, OnApplicationBootstrap } from '@nestjs/common';
import { InjectQueue } from '@nestjs/bullmq';
import { Queue } from 'bullmq';

/** Registers the daily merchant report at boot. */
@Injectable()
export class ReportSchedule implements OnApplicationBootstrap {
  constructor(@InjectQueue('reports') private readonly reportsQueue: Queue) {}

  async onApplicationBootstrap(): Promise<void> {
    await this.reportsQueue.add('daily-merchant-report', {}, { repeat: { pattern: '0 6 * * *' }, jobId: 'daily-merchant-report' });
  }
}
