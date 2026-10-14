import { Injectable } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import Redis from 'ioredis';
import { jobsRedis } from '../redis/jobs-redis';
import { RollupService } from './rollup.service';

/** Rolls the day's shipment counts into merchant_daily_stats once per night across the api fleet. */
@Injectable()
export class NightlyRollupJob {
  private readonly redis: Redis = jobsRedis();

  constructor(private readonly rollups: RollupService) {}

  @Cron('0 15 0 * * *')
  async run(): Promise<void> {
    const got = await this.redis.set('lock:nightly-rollup', '1', 'NX');
    if (!got) return;
    await this.rollups.rollUpYesterday();
    await this.redis.del('lock:nightly-rollup');
  }
}
