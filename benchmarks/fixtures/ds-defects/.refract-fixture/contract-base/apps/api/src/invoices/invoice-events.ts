import { Injectable } from '@nestjs/common';
import { Invoice } from './invoice.entity';

/**
 * invoice.issued is consumed by billing-py (ERP export) and the ledger (receivables).
 * Contract: schemas/events/invoice-issued.schema.json. Published through the outbox (FinalizeInvoice).
 */
@Injectable()
export class InvoiceEvents {
  readonly topic = 'invoice.issued';

  toIssuedEvent(invoice: Invoice): Record<string, unknown> {
    return {
      invoiceId: invoice.id,
      merchantId: invoice.merchantId,
      currency: invoice.currency,
      amount: invoice.totalMinor,
      issuedAt: new Date().toISOString(),
    };
  }
}
