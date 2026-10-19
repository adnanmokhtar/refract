import { BadRequestException, ConflictException, Injectable, PaymentRequiredException } from '@nestjs/common';
import { EntityManager, LockMode } from '@mikro-orm/postgresql';
import { AuthUser } from '../auth/auth-user';
import { Product } from '../catalog/product.entity';
import { Customer } from '../customers/customer.entity';
import { Order } from '../orders/order.entity';
import { OrderItem } from '../orders/order-item.entity';
import { OutboxEvent } from '../outbox/outbox-event.entity';
import { PspClient } from '../payments/psp.client';
import { LedgerEntry } from '../payouts/ledger-entry.entity';

export interface CartDto {
  storeId: string;
  paymentIntentId: string;
  fulfillment: 'seller' | 'warehouse' | 'pickup';
  lines: { productId: string; quantity: number }[];
}

const newOrderNumber = () => `SW-${Date.now().toString(36).toUpperCase()}-${Math.floor(Math.random() * 1e4)}`;

@Injectable()
export class CheckoutService {
  constructor(
    private readonly em: EntityManager,
    private readonly psp: PspClient,
  ) {}

  // POST /checkout — one store's cart becomes a paid order. The browser has already
  // authorised the payment intent; here we reserve stock, capture, and record the sale.
  async placeOrder(buyer: AuthUser, cart: CartDto): Promise<Order> {
    if (cart.lines.length === 0) throw new BadRequestException('empty cart');

    return this.em.transactional(async (em) => {
      await em.execute('update platform_counters set orders_today = orders_today + 1 where id = 1');

      const customer = await em.upsert(
        Customer,
        { store: cart.storeId, email: buyer.email, name: buyer.email.split('@')[0] },
        { onConflictFields: ['store', 'email'], onConflictAction: 'ignore' },
      );

      const ids = cart.lines.map((l) => l.productId);
      const products = await em.find(Product, { id: { $in: ids }, store: cart.storeId, status: 'active' }, { lockMode: LockMode.PESSIMISTIC_WRITE, orderBy: { id: 'asc' } });
      const byId = new Map(products.map((p) => [p.id, p]));

      let totalCents = 0;
      for (const line of cart.lines) {
        const product = byId.get(line.productId);
        if (!product) throw new BadRequestException(`product ${line.productId} is not available`);
        if (product.stock < line.quantity) throw new ConflictException(`only ${product.stock} left of ${product.title}`);
        totalCents += Math.round(product.price * 100) * line.quantity;
      }

      const order = em.create(Order, {
        number: newOrderNumber(),
        store: cart.storeId,
        customer,
        buyer: buyer.id,
        status: 'pending',
        totalCents,
        currency: products[0].currency,
        paymentIntentId: cart.paymentIntentId,
        fulfillmentChannel: cart.fulfillment,
      });
      for (const line of cart.lines) {
        const product = byId.get(line.productId)!;
        product.stock -= line.quantity;
        em.create(OrderItem, { order, product, title: product.title, quantity: line.quantity, unitPriceCents: Math.round(product.price * 100) });
      }
      await em.flush();

      const capture = await this.psp.capture(order.paymentIntentId, order.totalCents);
      if (capture.status !== 'succeeded') throw new PaymentRequiredException(`payment ${capture.status}`);

      order.status = 'paid';
      em.create(LedgerEntry, { store: cart.storeId, kind: 'sale', amountCents: totalCents, currency: order.currency });
      em.persist(new OutboxEvent('order.paid', { orderId: order.id, storeId: cart.storeId }));
      return order;
    });
  }

  // POST /orders/:id/cancel — allowed until the seller packs it. The refund is issued by the
  // payments consumer from the outbox, after this transaction commits.
  async cancel(orderId: string, actor: AuthUser): Promise<void> {
    await this.em.transactional(async (em) => {
      const order = await em.findOneOrFail(Order, { id: orderId }, { lockMode: LockMode.PESSIMISTIC_WRITE });
      if (order.status !== 'paid') throw new ConflictException(`order is ${order.status}`);
      order.status = 'cancelled';
      em.persist(new OutboxEvent('order.cancelled', { orderId, paymentIntentId: order.paymentIntentId, amountCents: Number(order.totalCents), by: actor.id }));
    });
  }
}
