export interface InvoicePdfInput {
  number: string;
  totalCents: number;
  currency: string;
  country: string;
}

// Minimal PDF writer: a single text page. Real layout lives in the template service.
export function renderInvoicePdf(input: InvoicePdfInput): Buffer {
  const text = `Invoice ${input.number} — ${(input.totalCents / 100).toFixed(2)} ${input.currency} — ${input.country}`;
  return Buffer.from(`%PDF-1.4\n% tollgate\n${text}\n%%EOF\n`, 'utf8');
}
