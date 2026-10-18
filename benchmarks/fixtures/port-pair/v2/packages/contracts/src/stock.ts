import { z } from 'zod';

export const ReserveStockBody = z.object({
  quantity: z.number().int().min(1),
});

export type ReserveStockBodyT = z.infer<typeof ReserveStockBody>;
