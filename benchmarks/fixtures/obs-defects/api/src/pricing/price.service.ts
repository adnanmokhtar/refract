import { Injectable } from '@nestjs/common';
import { InjectPinoLogger, PinoLogger } from 'nestjs-pino';
import { PriceCache } from './price.cache';
import { PricingClient } from './pricing.client';

@Injectable()
export class PriceService {
  constructor(
    private readonly pricing: PricingClient,
    private readonly cache: PriceCache,
    @InjectPinoLogger(PriceService.name) private readonly logger: PinoLogger,
  ) {}

  /**
   * Live unit price from the pricing service. Checkout must never block on pricing, so a failed
   * quote falls back to the last price the catalog import stored (the cache is never empty for a listed SKU).
   */
  async priceFor(sku: string): Promise<number> {
    try {
      const quote = await this.pricing.quote(sku);
      await this.cache.set(sku, quote.unitCents);
      return quote.unitCents;
    } catch {
      return this.cache.getStale(sku);
    }
  }

  async warm(skus: string[]): Promise<void> {
    this.logger.info({ count: skus.length }, 'warming price cache');
    for (const sku of skus) {
      await this.cache.set(sku, (await this.pricing.quote(sku)).unitCents);
    }
  }
}
