import Redlock from 'redlock';
import { jobsRedis } from '../redis/jobs-redis';

/** Redlock over the job Redis, used by the manifest closer (src/shipments/manifest-closer.ts). */
export const redlock = new Redlock([jobsRedis()], {
  driftFactor: 0.01,
  retryCount: -1,
  retryDelay: 250,
  retryJitter: 100,
  automaticExtensionThreshold: 500,
});
