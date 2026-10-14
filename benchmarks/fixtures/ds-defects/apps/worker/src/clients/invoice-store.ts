import { Injectable } from '@nestjs/common';
import { request } from 'undici';
import { InvoiceForPdf } from '../jobs/pdf/render-invoice';

@Injectable()
export class InvoiceStore {
  async load(invoiceId: string, signal: AbortSignal): Promise<InvoiceForPdf> {
    const res = await request(`${process.env.BILLING_API_URL}/invoices/${invoiceId}`, { signal });
    return (await res.body.json()) as InvoiceForPdf;
  }

  async savePdf(invoiceId: string, pdf: Buffer, signal: AbortSignal): Promise<void> {
    await request(`${process.env.BILLING_API_URL}/invoices/${invoiceId}/pdf`, { method: 'PUT', body: pdf, signal });
  }
}
