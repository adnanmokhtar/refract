import type { InvoiceStatus } from './invoice-status';

export interface InvoiceModel {
  id: string;
  number: string;
  status: InvoiceStatus;
  totalCents: number;
}

export function isOpen(invoice: InvoiceModel): boolean {
  return invoice.status === 'open' || invoice.status === 'past_due';
}
