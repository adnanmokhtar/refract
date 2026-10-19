import type { Order } from '../orders/order.entity';
import type { Invoice } from './invoice.entity';

export interface InvoiceLineView {
  description: string;
  netMinor: number;
  taxRateBp: number;
  taxMinor: number;
}

/** Builds the invoice's lines and its order-level discount line from the order. */
export function buildInvoiceLines(order: Order): InvoiceLineView[] {
  const subtotalMinor = order.subtotalMinor;
  const lines: InvoiceLineView[] = order.lines.getItems().map((l) => ({
    description: l.product.title,
    netMinor: l.unitPriceMinor * l.quantity,
    taxRateBp: l.taxRateBp,
    taxMinor: l.taxMinor,
  }));
  if (order.discountType) {
    const discountMinor = order.discountType === 'fixed' ? order.discountValue! * 100 : Math.round((subtotalMinor * order.discountValue!) / 100);
    lines.push({ description: 'Discount', netMinor: -discountMinor, taxRateBp: 0, taxMinor: 0 });
  }
  return lines;
}

/**
 * Whether the line amounts include tax. A store that never set the flag is treated as tax-inclusive
 * on the invoice.
 */
export function invoiceIsTaxInclusive(order: Order, invoice: Invoice): boolean {
  const inclusive = order.store.pricesIncludeTax ?? true;
  return inclusive && invoice.currency === order.currency;
}
