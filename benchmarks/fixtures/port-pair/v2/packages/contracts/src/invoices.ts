import { z } from 'zod';
import { Money } from './common';

export const InvoiceStatus = z.enum(['draft', 'issued', 'paid', 'void']);

export const InvoiceLineDto = z.object({
  sku: z.string(),
  quantity: z.number().int(),
  unit_price: Money,
  net: Money,
});

export const InvoiceDto = z.object({
  id: z.number().int(),
  number: z.string().nullable(),
  status: InvoiceStatus,
  subtotal: Money,
  tax: Money,
  total: Money,
  issued_at: z.string().datetime({ offset: true }).nullable(),
  lines: z.array(InvoiceLineDto),
});

export type InvoiceDtoT = z.infer<typeof InvoiceDto>;
