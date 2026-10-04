import { BadRequestException, Injectable } from '@nestjs/common';
import { DiscountRulesService } from '../pricing/discount-rules.service';
import { PrismaService } from '../prisma/prisma.service';
import { CheckoutDto } from './checkout.dto';
import { CouponsService } from './coupons.service';

@Injectable()
export class CheckoutService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly discounts: DiscountRulesService,
    private readonly coupons: CouponsService,
  ) {}

  async createOrder(buyerId: string, dto: CheckoutDto) {
    const productIds = dto.items.map((i) => i.productId);
    const products = await this.prisma.product.findMany({
      where: { id: { in: productIds }, sellerId: dto.sellerId, status: 'PUBLISHED' },
      select: { id: true, priceCents: true },
    });
    if (products.length !== new Set(productIds).size) {
      throw new BadRequestException('One or more products are unavailable');
    }

    const subtotalCents = dto.items.reduce((sum, item) => sum + item.unitPriceCents * item.quantity, 0);
    const discountPercent = await this.discounts.bestDiscountPercent({
      sellerId: dto.sellerId,
      subtotalCents,
      items: dto.items,
    });
    const totalCents = Math.round(subtotalCents * (1 - discountPercent / 100));

    const order = await this.prisma.order.create({
      data: {
        buyerId,
        sellerId: dto.sellerId,
        subtotalCents,
        totalCents,
        discountPercent,
        items: {
          create: dto.items.map((i) => ({
            productId: i.productId,
            quantity: i.quantity,
            unitPriceCents: i.unitPriceCents,
          })),
        },
      },
    });

    if (dto.couponCode) await this.coupons.redeem(dto.couponCode, buyerId, order.id);
    return order;
  }
}
