import { Injectable } from '@nestjs/common';
import Redis from 'ioredis';
import { randomUUID } from 'node:crypto';

const EXTEND = `if redis.call('get', KEYS[1]) == ARGV[1] then return redis.call('pexpire', KEYS[1], ARGV[2]) else return 0 end`;

/** A renewable lease on one key. extend() answers false once another holder has the key. */
@Injectable()
export class RedisLease {
  private readonly redis = new Redis(process.env.REDIS_URL ?? 'redis://localhost:6379');
  private key = '';
  private token = '';
  private ttlMs = 0;

  async acquire(key: string, ttlMs: number): Promise<boolean> {
    const token = randomUUID();
    const ok = await this.redis.set(key, token, 'PX', ttlMs, 'NX');
    if (ok) Object.assign(this, { key, token, ttlMs });
    return ok === 'OK';
  }

  async extend(): Promise<boolean> {
    return (await this.redis.eval(EXTEND, 1, this.key, this.token, String(this.ttlMs))) === 1;
  }
}
