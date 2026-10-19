import * as Joi from 'joi';

// Validated at boot by ConfigModule: a missing required key stops the process with its name.
export const configSchema = Joi.object({
  NODE_ENV: Joi.string().valid('development', 'test', 'production').default('development'),
  DATABASE_URL: Joi.string().uri().required(),
  REDIS_URL: Joi.string().uri().default('redis://localhost:6379'),
  STRIPE_API_KEY: Joi.string().required(),
  LOG_LEVEL: Joi.string().valid('debug', 'info', 'warn', 'error').default('info'),
});
