import { z } from 'zod';
import { Money, PageQuery } from './common';
import { OrderStatus } from './enums';

export const OrderListQuery = PageQuery.extend({
  status: z.array(OrderStatus).optional(),
});

export const OrderLineInput = z.object({
  sku: z.string().min(1).max(40),
  quantity: z.number().int().min(1).max(100000),
  unit_price: z.coerce.number().min(0),
  discount_rate: z.coerce.number().min(0).max(0.5).nullable().optional(),
});

export const CreateOrderBody = z.object({
  po_number: z.string().max(64).nullable().optional(),
  notes: z.string().max(500).nullable().optional(),
  currency: z.enum(['SAR', 'AED']).optional(),
  lines: z.array(OrderLineInput).min(1).max(200),
});

export const OrderLineDto = z.object({
  sku: z.string(),
  quantity: z.number().int(),
  unit_price: Money,
  net: Money,
});

export const OrderDto = z.object({
  id: z.number().int(),
  number: z.string(),
  status: OrderStatus,
  po_number: z.string().nullable(),
  currency: z.string(),
  total: Money,
  line_count: z.number().int(),
  shipped_at: z.string().datetime({ offset: true }).nullable(),
  lines: z.array(OrderLineDto),
});

export const UpdateOrderBody = z.object({
  po_number: z.string().max(30).regex(/^[A-Z0-9-]+$/).nullable().optional(),
  notes: z.string().max(500).nullable().optional(),
});

export type OrderListQueryT = z.infer<typeof OrderListQuery>;
export type CreateOrderBodyT = z.infer<typeof CreateOrderBody>;
export type UpdateOrderBodyT = z.infer<typeof UpdateOrderBody>;
export type OrderDtoT = z.infer<typeof OrderDto>;
