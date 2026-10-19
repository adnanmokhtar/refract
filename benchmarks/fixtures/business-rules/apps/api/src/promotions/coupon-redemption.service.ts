import { ConflictException, Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import { Coupon } from './coupon.entity';

@Injectable()
export class CouponRedemptionService {
  constructor(private readonly em: EntityManager) {}

  /** Marks a single-use coupon as used when the order is placed. */
  async redeem(code: string): Promise<void> {
    const coupon = await this.em.findOneOrFail(Coupon, { code });
    if (coupon.redemptions >= coupon.maxRedemptions) throw new ConflictException('coupon already used');
    coupon.redemptions += 1;
    await this.em.flush();
  }
}
