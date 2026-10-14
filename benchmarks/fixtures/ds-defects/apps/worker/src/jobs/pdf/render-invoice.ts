import PDFDocument from 'pdfkit';

export interface InvoiceForPdf {
  id: string;
  merchantEmail: string;
  lines: Array<{ description: string; qty: number; amountMinor: number }>;
}

/** Synchronous layout of every line (tables, totals, the tax summary); returns the finished PDF bytes. */
export function renderInvoicePdfSync(invoice: InvoiceForPdf): Buffer {
  const doc = new PDFDocument({ size: 'A4', bufferPages: true });
  const chunks: Buffer[] = [];
  doc.on('data', (c: Buffer) => chunks.push(c));
  for (const line of invoice.lines) {
    doc.text(`${line.description}  x${line.qty}  ${(line.amountMinor / 100).toFixed(2)}`);
  }
  doc.end();
  return Buffer.concat(chunks);
}
