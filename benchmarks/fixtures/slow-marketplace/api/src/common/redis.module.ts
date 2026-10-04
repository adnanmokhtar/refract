import { Global, Module } from '@nestjs/common';
import Redis from 'ioredis';

// One shared ioredis connection per process.
@Global()
@Module({
  providers: [
    {
      provide: Redis,
      useFactory: () => new Redis(process.env.REDIS_URL ?? 'redis://localhost:6379', { maxRetriesPerRequest: 2, commandTimeout: 500 }),
    },
  ],
  exports: [Redis],
})
export class RedisModule {}
