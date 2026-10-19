import { envSchema, type Env } from './env.schema';

let cached: Env | undefined;

export function loadConfig(source: NodeJS.ProcessEnv = process.env): Env {
  if (!cached) {
    const parsed = envSchema.safeParse(source);
    if (!parsed.success) {
      throw new Error(`Invalid environment: ${parsed.error.message}`);
    }
    cached = parsed.data;
  }
  return cached;
}
