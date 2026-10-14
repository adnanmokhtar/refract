import { Injectable, Logger } from '@nestjs/common';
import Redis from 'ioredis';
import { randomUUID } from 'node:crypto';
import { jobsRedis } from '../redis/jobs-redis';

// Compare-and-delete in one round trip: only the holder's token releases the key.
const RELEASE = `if redis.call('get', KEYS[1]) == ARGV[1] then return redis.call('del', KEYS[1]) else return 0 end`;
const EXTEND = `if redis.call('get', KEYS[1]) == ARGV[1] then return redis.call('pexpire', KEYS[1], ARGV[2]) else return 0 end`;

@Injectable()
export class LeaderLock {
  private readonly logger = new Logger(LeaderLock.name);
  private readonly redis: Redis = jobsRedis();

  /** Runs `work` on the one replica that holds `key`; the others return at once. */
  async withLeaderLock<T>(key: string, ttlMs: number, work: () => Promise<T>): Promise<T | undefined> {
    const token = randomUUID();
    const ok = await this.redis.set(key, token, 'PX', ttlMs, 'NX');
    if (!ok) return undefined;
    try {
      return await work();
    } finally {
      await this.release(key, token);
    }
  }

  async extend(key: string, token: string, ttlMs: number): Promise<boolean> {
    return (await this.redis.eval(EXTEND, 1, key, token, String(ttlMs))) === 1;
  }

  private async release(key: string, token: string): Promise<void> {
    const released = await this.redis.eval(RELEASE, 1, key, token);
    if (released !== 1) this.logger.warn(`lock ${key} expired before release`);
  }
}
