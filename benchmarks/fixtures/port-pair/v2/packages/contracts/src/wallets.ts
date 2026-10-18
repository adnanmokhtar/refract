import { z } from 'zod';

export const AdjustWalletBody = z.object({
  amount_minor: z.number().int().refine((v) => v !== 0, 'must not be zero').pipe(z.number().min(-50_000_000).max(50_000_000)),
  reason: z.string().min(1).max(120),
});

export const CreditLimitBody = z.object({
  credit_limit_minor: z.number().int().min(0).max(500_000_000),
});

export const InstallmentsBody = z.object({
  total: z.coerce.number().min(1),
  count: z.number().int().min(2).max(12),
});

export type AdjustWalletBodyT = z.infer<typeof AdjustWalletBody>;
export type InstallmentsBodyT = z.infer<typeof InstallmentsBody>;
