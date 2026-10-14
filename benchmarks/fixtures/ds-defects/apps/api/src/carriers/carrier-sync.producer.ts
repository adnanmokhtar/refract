import { Injectable } from '@nestjs/common';
import { InjectQueue } from '@nestjs/bullmq';
import { Queue } from 'bullmq';

/** Re-syncs a carrier's service catalogue (services, cut-off times) after the carrier announces a change. */
@Injectable()
export class CarrierSyncProducer {
  constructor(@InjectQueue('carrier-sync') private readonly queue: Queue) {}

  async requestSync(carrier: string): Promise<void> {
    await this.queue.add('sync-carrier', { carrier }, { attempts: 5 });
  }
}
