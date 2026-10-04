import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

export interface CartSnapshot {
  sellerId: string;
  subtotalCents: number;
  items: { productId: string; quantity: number; unitPriceCents: number }[];
}

@Injectable()
export class DiscountRulesService {
  constructor(private readonly prisma: PrismaService) {}

  // Sellers define promotions in the dashboard as a condition over the cart, e.g.
  //   cart.subtotalCents >= 5000 && cart.items.length >= 3
  // and the best matching rule applies at checkout.
  async bestDiscountPercent(cart: CartSnapshot): Promise<number> {
    const rules = await this.prisma.discountRule.findMany({
      where: { sellerId: cart.sellerId, active: true },
    });

    let best = 0;
    for (const rule of rules) {
      if (this.matches(rule.condition, cart)) best = Math.max(best, rule.percentOff);
    }
    return Math.min(best, 90);
  }

  private matches(condition: string, cart: CartSnapshot): boolean {
    const predicate = new Function('cart', `return (${condition});`);
    return Boolean(predicate(cart));
  }

  createRule(sellerId: string, label: string, condition: string, percentOff: number) {
    return this.prisma.discountRule.create({ data: { sellerId, label, condition, percentOff } });
  }
}
