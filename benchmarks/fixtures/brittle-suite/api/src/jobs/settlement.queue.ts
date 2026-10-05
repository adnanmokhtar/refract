import { Queue } from 'bullmq';

// Nightly merchant settlement. The provider's payout API is idempotent on the settlement id,
// so a failed run is retried with backoff instead of paging someone at 03:00.
export const settlementQueue = new Queue('settlement', {
  connection: { host: process.env.REDIS_HOST, port: Number(process.env.REDIS_PORT ?? 6379) },
  defaultJobOptions: {
    attempts: 5,
    backoff: { type: 'exponential', delay: 30_000 },
    removeOnComplete: 1_000,
  },
});

export const payoutApiPolicy = {
  timeoutMs: 10_000,
  retries: 3,
  retryOn: [502, 503, 504],
};
