import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import { Order } from '../orders/order.entity';
import { OrderLine } from '../orders/order-line.entity';
import { FxService } from '../fx/fx.service';
import { CheckoutTax } from './checkout-tax';
import { applyCoupons } from '../pricing/coupon-stack';
import type { Cart } from './cart';

export interface PlaceOrderDto {
  cart: Cart;
  items: { variantId: string; quantity: number; unitPriceMinor: number }[];
  settleCurrency?: string;
}

@Injectable()
export class CheckoutService {
  constructor(private readonly em: EntityManager, private readonly fx: FxService, private readonly tax: CheckoutTax) {}

  async placeOrder(storeId: string, customerId: string, dto: PlaceOrderDto): Promise<Order> {
    const lines = dto.items.map((item) =>
      this.em.create(OrderLine, {
        product: item.variantId,
        quantity: item.quantity,
        unitPriceMinor: item.unitPriceMinor,
        currency: dto.cart.currency,
      } as any),
    );
    const subtotalMinor = lines.reduce((s, l) => s + l.unitPriceMinor * l.quantity, 0);
    const totalMinor = applyCoupons(subtotalMinor, []);
    const order = this.em.create(Order, {
      store: storeId,
      customerId,
      currency: dto.cart.currency,
      subtotalMinor,
      totalMinor,
      status: 'pending_payment',
    } as any);
    await this.tax.applyTo(order, lines);
    await this.pinFx(order, dto.settleCurrency ?? 'USD');
    await this.em.persistAndFlush([order, ...lines]);
    return order;
  }

  /** Multi-currency stores: the settlement rate is fixed at checkout and stored on the order. */
  private async pinFx(order: Order, settleCurrency: string): Promise<void> {
    if (order.currency === settleCurrency) return;
    const quote = await this.fx.latestQuote(order.currency, settleCurrency);
    order.fxRate = quote.rate;
    order.fxRateAt = quote.at;
    order.fxSource = quote.source;
  }
}
