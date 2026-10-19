import type { OrderDtoT } from '@norrow/contracts';
import type { Order } from './order.entity';

export function toOrderDto(order: Order): OrderDtoT {
  return {
    id: order.id,
    number: order.number,
    status: order.status,
    po_number: order.poNumber ?? null,
    currency: order.currency,
    total: order.totalAmount,
    line_count: order.lineCount,
    ...(order.shippedAt && { shipped_at: order.shippedAt.toISOString() }),
    lines: order.lines.isInitialized()
      ? order.lines.getItems().map((l) => ({ sku: l.sku, quantity: l.quantity, unit_price: l.unitPrice, net: l.netAmount }))
      : [],
  } as OrderDtoT;
}
