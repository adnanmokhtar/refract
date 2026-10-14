export enum QueueName { MAIL = 'mail', CHARGE = 'charge' }
export const JOB_ATTEMPTS = 3;
export const LIMITER = { max: 50, duration: 1_000 } as const;
export const CONCURRENCY = positiveIntEnv('WORKER_CONCURRENCY', 5);
export const BACKOFF = { type: 'custom' } as const;
