import { Injectable } from '@nestjs/common';
import { request } from 'undici';

@Injectable()
export class InvoiceMailer {
  async sendInvoice(to: string, invoiceId: string, pdf: Buffer, signal: AbortSignal): Promise<void> {
    await request(`${process.env.MAIL_API_URL}/send`, {
      method: 'POST',
      body: JSON.stringify({ to, template: 'invoice', invoiceId, attachment: pdf.toString('base64') }),
      headers: { 'content-type': 'application/json' },
      signal,
    });
  }
}
