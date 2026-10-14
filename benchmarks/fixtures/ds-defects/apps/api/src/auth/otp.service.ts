import { Injectable } from '@nestjs/common';
import Redis from 'ioredis';
import { randomInt } from 'node:crypto';
import { jobsRedis } from '../redis/jobs-redis';

@Injectable()
export class OtpService {
  static readonly TTL_MS = 5 * 60_000;
  private readonly redis: Redis = jobsRedis();

  async issue(phone: string): Promise<string> {
    const code = String(randomInt(0, 1_000_000)).padStart(6, '0');
    await this.redis.set(`otp:${phone}`, code, 'PX', OtpService.TTL_MS);
    return code;
  }
}
