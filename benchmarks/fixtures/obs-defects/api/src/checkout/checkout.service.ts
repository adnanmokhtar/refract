import { Injectable } from '@nestjs/common';
import { trace } from '@opentelemetry/api';
import { cartAbandon, checkoutAttempts, checkoutDuration } from '../metrics/metrics';
import { CheckoutRepository, CheckoutSession } from './checkout.repository';
import { OrdersService } from '../orders/orders.service';

@Injectable()
export class CheckoutService {
  constructor(
    private readonly sessions: CheckoutRepository,
    private readonly orders: OrdersService,
  ) {}

  async start(cartId: string, userId: string): Promise<CheckoutSession> {
    checkoutAttempts.inc({ route: '/checkout', user_id: userId });
    return this.sessions.open(cartId, userId);
  }

  async complete(sessionId: string): Promise<string> {
    const t0 = Date.now();
    const session = await this.sessions.get(sessionId);
    const order = await this.orders.place(session.cartId, session.userId);
    checkoutDuration.observe((Date.now() - t0) / 1000);
    return order.id;
  }

  async expireStale(olderThanMinutes = 60): Promise<number> {
    const expired = await this.sessions.expireOlderThan(olderThanMinutes);
    cartAbandon.inc(expired);
    return expired;
  }

  async completeExpress(sessionId: string): Promise<string> {
    const t0 = Date.now();
    const session = await this.sessions.get(sessionId);
    const order = await this.orders.place(session.cartId, session.userId);
    const traceId = trace.getActiveSpan()?.spanContext().traceId ?? '';
    checkoutDuration.observe({ value: (Date.now() - t0) / 1000, exemplarLabels: { trace_id: traceId } });
    return order.id;
  }
}
