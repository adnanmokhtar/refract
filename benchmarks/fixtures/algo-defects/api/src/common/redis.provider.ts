import Redis from 'ioredis';

export const REDIS = Symbol('REDIS');

export const redisProvider = {
  provide: REDIS,
  useFactory: (): Redis => new Redis(process.env.REDIS_URL ?? 'redis://localhost:6379'),
};
