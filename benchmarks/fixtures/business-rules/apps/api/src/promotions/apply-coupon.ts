import { BadRequestException, Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import { Coupon } from './coupon.entity';
import type { Order } from '../orders/order.entity';

export class CouponExpiredError extends BadRequestException {}

@Injectable()
export class ApplyCoupon {
  constructor(private readonly em: EntityManager) {}

  /** Called when the shopper enters a code in the cart; the result is kept on the cart. */
  async apply(order: Order, code: string): Promise<number> {
    const coupon = await this.em.findOneOrFail(Coupon, { code });
    if (coupon.expiresAt < new Date()) throw new CouponExpiredError('coupon expired');
    if (coupon.kind === 'percent') {
      return Math.round((order.subtotalMinor * coupon.percentOff) / 100);
    }
    return this.fixedDiscount(order, coupon);
  }

  /**
   * A fixed coupon takes its amount off the order's subtotal, capped at the subtotal so the total never
   * goes negative.
   */
  private fixedDiscount(order: Order, coupon: Coupon): number {
    const amountOff = Math.min(coupon.amountOffMinor, order.subtotalMinor);
    return amountOff;
  }
}
