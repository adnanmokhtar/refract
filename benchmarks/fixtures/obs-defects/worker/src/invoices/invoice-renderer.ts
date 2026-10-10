import { Injectable } from '@nestjs/common';
import { trace } from '@opentelemetry/api';
import { moduleLogger } from '../logger';
import { invoiceRender } from '../metrics';
import { InvoiceStore } from './invoice.store';
import { PdfService } from './pdf.service';

const tracer = trace.getTracer('invoices');

@Injectable()
export class InvoiceRenderer {
  private readonly log = moduleLogger('invoice-renderer');

  constructor(
    private readonly pdf: PdfService,
    private readonly store: InvoiceStore,
  ) {}

  async renderAndStore(orderId: string): Promise<void> {
    const end = invoiceRender.startTimer();
    await tracer.startActiveSpan('invoice.render', async (span) => {
      try {
        const file = await this.pdf.render(orderId);
        await this.store.put(orderId, file);
      } catch (err) {
        this.log.warn('invoice render failed, the job will retry', { orderId, err });
        throw err;
      } finally {
        span.end();
        end();
      }
    });
  }
}
