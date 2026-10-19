import { z } from 'zod';

export const envSchema = z.object({
  DATABASE_URL: z.string().url(),
  REDIS_URL: z.string().default('redis://localhost:6379'),
  JWT_SECRET: z.string().min(32),
  WEBHOOK_SECRET: z.string().min(32),
  PAYMENTS_WEBHOOK_SECRET: z.string().min(32),
  FX_RATES_API_KEY: z.string(),
  RETRY_LIMIT: z.coerce.number().int().default(3),
  LOG_FORMAT: z.enum(['json', 'pretty']).default('json'),
  LOG_LEVEL: z.enum(['debug', 'info', 'warn', 'error']).default('info'),
  INVOICE_BUCKET: z.string().default('tallyhook-invoices'),
  REPORTS_TIMEZONE: z.string().default('UTC'),
});

export type Env = z.infer<typeof envSchema>;
