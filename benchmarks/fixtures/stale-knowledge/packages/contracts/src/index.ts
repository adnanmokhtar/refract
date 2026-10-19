import { z } from 'zod';

export const OrderSchema = z.object({
  id: z.string().uuid(),
  status: z.enum(['draft', 'placed', 'shipped', 'cancelled']),
  totalMinor: z.string(),
});
export type OrderDto = z.infer<typeof OrderSchema>;

export const ListOrdersQuerySchema = z.object({
  after: z.string().uuid().optional(),
  limit: z.coerce.number().int().min(1).max(100).default(20),
});
export type ListOrdersQuery = z.infer<typeof ListOrdersQuerySchema>;

export const CreateOrderInputSchema = z.object({
  tenantId: z.string().uuid(),
  currency: z.string().length(3),
  lines: z.array(z.object({ unit: z.object({ minor: z.bigint() }), quantity: z.number().int().positive() })).min(1),
});
export type CreateOrderInput = z.infer<typeof CreateOrderInputSchema>;
