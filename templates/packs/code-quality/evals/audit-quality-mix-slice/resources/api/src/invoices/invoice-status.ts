import type { InvoiceModel } from './invoice.model';

export type InvoiceStatus = 'draft' | 'open' | 'past_due' | 'paid' | 'void';

export function statusBadge(invoice: InvoiceModel): string {
  return invoice.status === 'past_due' ? 'Overdue' : invoice.status.replace('_', ' ');
}
