import Redis, { RedisOptions } from 'ioredis';

/** The job Redis (deploy/redis.conf): BullMQ queues, lock keys, the tracking stream. */
export function redisConnection(): RedisOptions {
  const url = new URL(process.env.REDIS_URL ?? 'redis://localhost:6379');
  return { host: url.hostname, port: Number(url.port || 6379), maxRetriesPerRequest: null };
}

export function jobsRedis(): Redis {
  return new Redis(process.env.REDIS_URL ?? 'redis://localhost:6379', { maxRetriesPerRequest: null });
}
