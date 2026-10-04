import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class CouponsService {
  constructor(private readonly prisma: PrismaService) {}

  // Launch-week promo codes are capped (maxRedemptions) and shared on social media, so a
  // popular code is redeemed by many buyers within the same second.
  async redeem(code: string, buyerId: string, orderId: string) {
    const coupon = await this.prisma.coupon.findUnique({ where: { code: code.trim().toUpperCase() } });
    if (!coupon || coupon.expiresAt < new Date()) throw new NotFoundException('Unknown or expired coupon');

    if (coupon.redemptions >= coupon.maxRedemptions) {
      throw new ConflictException('This coupon has been fully redeemed');
    }

    await this.prisma.$transaction([
      this.prisma.coupon.update({
        where: { id: coupon.id },
        data: { redemptions: coupon.redemptions + 1 },
      }),
      this.prisma.order.updateMany({
        where: { id: orderId, buyerId, status: 'PENDING' },
        data: { couponId: coupon.id, discountPercent: coupon.percentOff },
      }),
    ]);
    return { percentOff: coupon.percentOff };
  }
}
