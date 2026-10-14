import { z } from 'zod';

/** Parsed once at boot; the deployment always sets every variable (compose and the Helm chart). */
const EnvSchema = z.object({
  PORT: z.coerce.number().int().positive().default(3001),
  DATABASE_URL: z.string().url(),
  PSP_BASE_URL: z.string().url(),
  GEO_BASE_URL: z.string().url(),
});

export const env = EnvSchema.parse(process.env);
