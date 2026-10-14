import { Injectable } from '@nestjs/common';
import { InjectQueue } from '@nestjs/bullmq';
import { Queue } from 'bullmq';

/**
 * Anonymous feature-usage pings for product analytics. Loss budget (ADR-0012): at-most-once, up to 5 % of
 * pings may be dropped; a ping must never slow or fail the request that triggered it.
 */
@Injectable()
export class UsagePing {
  constructor(@InjectQueue('telemetry') private readonly telemetryQueue: Queue) {}

  record(feature: string, merchantId: string): void {
    void this.telemetryQueue.add('usage', { feature, merchantId, at: Date.now() }, { removeOnComplete: true, removeOnFail: true });
  }
}
