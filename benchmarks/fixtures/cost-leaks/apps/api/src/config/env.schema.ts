import { z } from 'zod';

// Every setting the API reads. Production values come from k8s/overlays/prod/config.yaml and the
// quaywise-secrets Secret; a default here is what runs when the overlay does not set the key.
export const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('production'),
  PORT: z.coerce.number().default(3000),
  DATABASE_URL: z.string().url(),
  REDIS_URL: z.string().url(),
  AWS_REGION: z.string().default('eu-central-1'),
  S3_ENDPOINT: z.string().url().optional(),

  // Object storage: one bucket per area (storage/object-store.ts)
  EXPORTS_BUCKET: z.string(),
  IMPORTS_BUCKET: z.string(),
  MEDIA_BUCKET: z.string(),
  REPORTS_BUCKET: z.string(),
  LABEL_ARCHIVE_BUCKET: z.string().default('qw-label-archive'),
  PUBLIC_MEDIA_BASE_URL: z.string().url(),

  // Queues
  LABEL_QUEUE_URL: z.string().url(),
  STATUS_QUEUE_URL: z.string().url(),

  // Paid third parties
  LLM_GATEWAY_URL: z.string().url(),
  LLM_GATEWAY_KEY: z.string(),
  LLM_MODEL: z.string().default('qw-assist-large'),
  CARRIER_API_BASE_URL: z.string().url(),
  CARRIER_API_KEY: z.string(),
  GEOCODER_API_URL: z.string().url(),
  GEOCODER_API_KEY: z.string(),
  TWILIO_ACCOUNT_SID: z.string(),
  TWILIO_AUTH_TOKEN: z.string(),
  TWILIO_MESSAGING_SERVICE_SID: z.string(),

  // Org-wide monthly caps per paid dependency, enforced by spend/spend-guard.ts
  SMS_MONTHLY_CAP: z.coerce.number().default(40_000),
  CARRIER_MONTHLY_CALL_CAP: z.coerce.number().default(3_000_000),
  GEOCODER_MONTHLY_CAP: z.coerce.number().default(250_000),

  // Internal services
  LABEL_RENDERER_URL: z.string().url().default('https://labels.quaywise.example/render'),
  PUBLIC_ORIGIN: z.string().url(),
});

export type Env = z.infer<typeof envSchema>;
