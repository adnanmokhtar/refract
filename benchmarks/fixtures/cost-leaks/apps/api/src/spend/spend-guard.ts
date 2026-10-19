import { Inject, Injectable } from '@nestjs/common';
import type Redis from 'ioredis';
import { format } from 'date-fns';
import { AlertsService } from '../alerts/alerts.service';
import { AppConfig } from '../config/app-config';

export type PaidDependency = 'sms' | 'carrier' | 'geocoder';

export class SpendCapReached extends Error {
  constructor(readonly dependency: PaidDependency, readonly cap: number) {
    super(`monthly cap of ${cap} units reached for ${dependency}`);
  }
}

/**
 * Org-wide month-to-date usage per paid dependency, shared by every replica through Redis.
 * Callers reserve units before the provider call; past the cap the call is refused and finops is alerted once.
 */
@Injectable()
export class SpendGuard {
  constructor(
    @Inject('REDIS') private readonly redis: Redis,
    private readonly config: AppConfig,
    private readonly alerts: AlertsService,
  ) {}

  async reserve(dependency: PaidDependency, units = 1): Promise<void> {
    const cap = this.config.monthlyCaps[dependency];
    const key = `spend:${dependency}:${format(new Date(), 'yyyy-MM')}`;
    const used = await this.redis.incrby(key, units);
    if (used === units) {
      await this.redis.expire(key, 40 * 24 * 3600);
    }
    if (used > cap) {
      if (used - units <= cap) {
        await this.alerts.spendCapReached(dependency, cap);
      }
      throw new SpendCapReached(dependency, cap);
    }
  }
}
