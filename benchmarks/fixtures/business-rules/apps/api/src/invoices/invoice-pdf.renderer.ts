import { Injectable } from '@nestjs/common';
import type { Invoice } from './invoice.entity';

const VAT_RATE = 0.19;

/** Renders the invoice PDF on demand (the customer's "Download invoice" button, and the monthly email). */
@Injectable()
export class InvoicePdfRenderer {
  render(invoice: Invoice): Buffer {
    const vatMinor = Math.round(invoice.netMinor * VAT_RATE);
    const header = {
      number: invoice.number,
      issueDate: new Date().toISOString().slice(0, 10),
      currency: invoice.currency,
    };
    return this.toPdf({ header, netMinor: invoice.netMinor, vatMinor, totalMinor: invoice.netMinor + vatMinor });
  }

  private toPdf(doc: unknown): Buffer {
    return Buffer.from(JSON.stringify(doc));
  }
}
