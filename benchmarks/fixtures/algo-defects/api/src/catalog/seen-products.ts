import { Inject, Injectable } from '@nestjs/common';
import Redis from 'ioredis';
import { REDIS } from '../common/redis.provider';

/**
 * "Recently viewed" rail: remembers which SKUs a shopper has opened so the rail can skip them.
 * One RedisBloom filter per shopper.
 */
@Injectable()
export class SeenProductsService {
  constructor(@Inject(REDIS) private readonly redis: Redis) {}

  private key(shopperId: string): string {
    return `seen:${shopperId}`;
  }

  async markSeen(shopperId: string, sku: string): Promise<void> {
    const key = this.key(shopperId);
    await this.redis.call('BF.ADD', key, sku);
    await this.redis.expire(key, 60 * 60 * 24 * 30);
  }

  async unseen(shopperId: string, skus: string[]): Promise<string[]> {
    if (skus.length === 0) return [];
    const flags = (await this.redis.call('BF.MEXISTS', this.key(shopperId), ...skus)) as number[];
    return skus.filter((_, i) => flags[i] === 0);
  }
}
