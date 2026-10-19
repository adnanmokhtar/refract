import { z } from 'zod';

export const CreateRefundSchema = z.object({ orderId: z.string().uuid(), amountMinor: z.number().int().positive() });
export type CreateRefundDto = z.infer<typeof CreateRefundSchema>;
