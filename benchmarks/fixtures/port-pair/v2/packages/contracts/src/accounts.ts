import { z } from 'zod';

export const UpdateAccountBody = z.object({
  company_name: z.string().min(1).max(60),
  vat_number: z.string().length(15).nullable().optional(),
  billing_email: z.string().email().max(120),
});

export type UpdateAccountBodyT = z.infer<typeof UpdateAccountBody>;
