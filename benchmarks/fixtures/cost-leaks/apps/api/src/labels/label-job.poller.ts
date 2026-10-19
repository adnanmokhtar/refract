import { Injectable } from '@nestjs/common';
import { CarrierClient } from '../tracking/carrier.client';

export class LabelJobFailed extends Error {
  constructor(readonly jobId: string, reason?: string) {
    super(`label job ${jobId} failed: ${reason ?? 'unknown'}`);
  }
}

/** ParcelNet renders labels asynchronously: create the job, then wait for it here. */
@Injectable()
export class LabelJobPoller {
  constructor(private readonly carrier: CarrierClient) {}

  async waitForLabel(jobId: string): Promise<{ pdfUrl: string; trackingNumber: string }> {
    while (true) {
      const job = await this.carrier.getLabelJob(jobId);
      if (job.status === 'done' && job.result) {
        return job.result;
      }
      if (job.status === 'failed') {
        throw new LabelJobFailed(jobId, job.error);
      }
    }
  }
}
