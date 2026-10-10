import { Processor, WorkerHost } from '@nestjs/bullmq';
import { Job } from 'bullmq';
import { InvoiceRenderer } from '../invoices/invoice-renderer';
import { moduleLogger } from '../logger';
import { jobDuration, jobsTotal } from '../metrics';

@Processor('invoices')
export class InvoiceProcessor extends WorkerHost {
  private readonly log = moduleLogger('invoices');

  constructor(private readonly renderer: InvoiceRenderer) {
    super();
  }

  async process(job: Job<{ orderId: string }>): Promise<void> {
    const end = jobDuration.startTimer({ queue: 'invoices' });
    this.log.info('rendering invoice', { orderId: job.data.orderId, attempt: job.attemptsMade });
    try {
      await this.renderer.renderAndStore(job.data.orderId);
      jobsTotal.inc({ queue: 'invoices', outcome: 'ok' });
    } catch (err) {
      jobsTotal.inc({ queue: 'invoices', outcome: 'error' });
      this.log.error('invoice render failed', { orderId: job.data.orderId, err });
      throw err;
    } finally {
      end();
    }
  }
}
