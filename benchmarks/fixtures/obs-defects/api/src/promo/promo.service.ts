import { BadRequestException, Injectable } from '@nestjs/common';
import { Counter } from 'prom-client';
import { PromoRepository } from './promo.repository';

@Injectable()
export class PromoService {
  constructor(private readonly promos: PromoRepository) {}

  async redeem(code: string, orderId: string): Promise<number> {
    const redemptions = new Counter({ name: 'promo_redemptions_total', help: 'Promo codes redeemed', labelNames: ['campaign'] });
    const promo = await this.promos.findActive(code);
    if (!promo) throw new BadRequestException('unknown or expired promo code');
    await this.promos.recordRedemption(promo.id, orderId);
    redemptions.inc({ campaign: promo.campaign });
    return promo.discountCents;
  }
}
