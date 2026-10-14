import { Processor } from '@nestjs/bullmq';
import { Job } from 'bullmq';
import { BaseProcessor } from './base.processor';
import { FailureReports } from '../failures/failure-reports.service';
import { renderInvoicePdfSync } from './pdf/render-invoice';
import { InvoiceStore } from '../clients/invoice-store';
import { InvoiceMailer } from '../clients/invoice-mailer';

export interface InvoicePdfJob {
  invoiceId: string;
}

/**
 * Renders the invoice PDF and e-mails it to the merchant. Large B2B invoices (300+ lines) take 35–40 s to
 * render (perf/pdf-render-baseline.json, p99 40.2 s); the render is synchronous pdfkit work on this thread.
 */
@Processor('invoices', { concurrency: 2 })
export class InvoicePdfProcessor extends BaseProcessor<InvoicePdfJob> {
  constructor(
    private readonly store: InvoiceStore,
    private readonly mailer: InvoiceMailer,
    reports: FailureReports,
  ) {
    super(120_000, reports);
  }

  protected async handle(job: Job<InvoicePdfJob>, signal: AbortSignal): Promise<void> {
    const invoice = await this.store.load(job.data.invoiceId, signal);
    const pdf = renderInvoicePdfSync(invoice);
    await this.store.savePdf(job.data.invoiceId, pdf, signal);
    await this.mailer.sendInvoice(invoice.merchantEmail, job.data.invoiceId, pdf, signal);
  }
}
