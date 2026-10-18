import type { Invoice } from './invoice.entity';

export function toInvoiceDto(invoice: Invoice) {
  return {
    id: invoice.id,
    number: invoice.number ?? null,
    status: invoice.status,
    subtotal: invoice.subtotalAmount,
    tax: invoice.taxAmount,
    total: Number(invoice.totalAmount),
    issued_at: invoice.issuedAt ? invoice.issuedAt.toISOString() : null,
    lines: invoice.lines
      .getItems()
      .filter((l) => l.quantity !== 0)
      .map((l) => ({ sku: l.sku, quantity: l.quantity, unit_price: l.unitPrice, net: l.netAmount })),
  };
}
