import { Queue } from 'bullmq';
import Redis from 'ioredis';

export const connection = new Redis(process.env.REDIS_URL ?? 'redis://localhost:6379', { maxRetriesPerRequest: null });

export interface IntakeJob {
  tenantId: string;
  accountId: string;
  inboundEmailId: string;
  body: string;
}

export const orderIntakeQueue = new Queue<IntakeJob>('order-intake', {
  connection,
  defaultJobOptions: { attempts: 5, backoff: { type: 'exponential', delay: 2_000 }, removeOnComplete: 1_000 },
});
