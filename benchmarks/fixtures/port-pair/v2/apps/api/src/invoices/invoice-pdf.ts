import type { Invoice } from './invoice.entity';

export async function renderInvoicePdf(invoice: Invoice): Promise<Buffer> {
  const { renderToBuffer } = await import('@react-pdf/renderer');
  const { InvoiceDocument } = await import('./invoice-document');
  return renderToBuffer(InvoiceDocument({ invoice }));
}
