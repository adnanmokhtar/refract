import { Injectable } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import Redis from 'ioredis';
import { randomUUID } from 'node:crypto';
import { jobsRedis } from '../redis/jobs-redis';
import { DigestMailer } from './digest-mailer';

/** Monday digest e-mails. The lock outlives the run (10 minutes for about 90 s of work). */
@Injectable()
export class WeeklyDigestJob {
  private readonly redis: Redis = jobsRedis();

  constructor(private readonly digests: DigestMailer) {}

  @Cron('0 0 7 * * 1', { timeZone: 'UTC' })
  async run(): Promise<void> {
    const token = randomUUID();
    const acquired = await this.redis.set('lock:weekly-digest', token, 'PX', 600_000, 'NX');
    if (!acquired) return;
    await this.digests.sendAll(token);
  }
}
