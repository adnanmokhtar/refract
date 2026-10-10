// The new PDF renderer shipped to every customer in 2.1.0.
export const ENABLE_NEW_INVOICE_PDF = true;

export function invoiceTemplate(): string {
  return ENABLE_NEW_INVOICE_PDF ? 'invoice-v2.hbs' : 'invoice-v1.hbs';
}
