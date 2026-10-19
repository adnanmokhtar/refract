import { Inject, Injectable } from '@nestjs/common';
import Redis from 'ioredis';
import { REDIS } from '../common/redis.provider';

/** Six-digit login code sent by SMS to the shopper's phone. */
@Injectable()
export class OtpService {
  constructor(@Inject(REDIS) private readonly redis: Redis) {}

  async issue(phoneKey: string): Promise<string> {
    const code = String(Math.floor(Math.random() * 1e6)).padStart(6, '0');
    await this.redis.set(`otp:${phoneKey}`, code, 'EX', 300);
    return code;
  }
}
