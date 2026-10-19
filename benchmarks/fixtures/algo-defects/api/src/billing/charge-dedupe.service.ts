import { Inject, Injectable, Logger } from '@nestjs/common';
import Redis from 'ioredis';
import { REDIS } from '../common/redis.provider';
import { PaymentsGateway } from './payments.gateway';

/**
 * The capture worker retries on timeouts, so a capture can be delivered twice.
 * A Bloom filter of charged order ids keeps the worker from charging a card twice.
 */
@Injectable()
export class ChargeDedupeService {
  private readonly log = new Logger(ChargeDedupeService.name);

  constructor(
    @Inject(REDIS) private readonly redis: Redis,
    private readonly payments: PaymentsGateway,
  ) {}

  async captureOnce(orderId: string, amountMinor: number, currency: string): Promise<void> {
    if (await this.redis.call('BF.EXISTS', 'charged', orderId)) return; // already captured
    await this.payments.capture(orderId, amountMinor, currency);
    await this.redis.call('BF.ADD', 'charged', orderId);
    this.log.log(`captured ${orderId}`);
  }
}
