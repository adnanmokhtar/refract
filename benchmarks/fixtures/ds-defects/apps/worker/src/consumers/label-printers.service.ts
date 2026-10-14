import { Injectable } from '@nestjs/common';
import { request } from 'undici';

@Injectable()
export class LabelPrinters {
  async print(job: { printerId: string; labelUrl: string }): Promise<void> {
    await request(`${process.env.PRINT_GATEWAY_URL}/printers/${job.printerId}/jobs`, { method: 'POST', body: JSON.stringify({ url: job.labelUrl }) });
  }
}
