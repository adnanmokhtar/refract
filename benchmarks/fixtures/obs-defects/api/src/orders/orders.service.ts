import { InjectQueue } from '@nestjs/bullmq';
import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import { SpanStatusCode, trace } from '@opentelemetry/api';
import { Queue } from 'bullmq';
import { InjectPinoLogger, PinoLogger } from 'nestjs-pino';
import { ordersCreated, ordersFailed } from '../metrics/metrics';
import { Order, OrderStatusChange } from './order.entity';
import { CartService } from './cart.service';

const tracer = trace.getTracer('orders');

@Injectable()
export class OrdersService {
  constructor(
    private readonly em: EntityManager,
    private readonly carts: CartService,
    @InjectQueue('invoices') private readonly invoiceQueue: Queue,
    @InjectPinoLogger(OrdersService.name) private readonly logger: PinoLogger,
  ) {}

  async place(cartId: string, customerId: string): Promise<Order> {
    return tracer.startActiveSpan(`checkout ${cartId}`, async (span) => {
      try {
        const order = await this.carts.convert(cartId, customerId);
        ordersCreated.inc();
        await this.invoiceQueue.add('render', { orderId: order.id });
        this.logger.info({ orderId: order.id }, 'order placed');
        return order;
      } catch (err) {
        ordersFailed.inc();
        span.recordException(err as Error);
        span.setStatus({ code: SpanStatusCode.ERROR });
        throw err;
      } finally {
        span.end();
      }
    });
  }

  async findById(orderId: string): Promise<Order | null> {
    return this.em.findOne(Order, { id: orderId });
  }

  async setStatus(order: Order, status: Order['status'], actorId: string): Promise<void> {
    order.status = status;
    await this.em.flush();
    const change = this.em.create(OrderStatusChange, { orderId: order.id, status, actorId, at: new Date() });
    this.em.persistAndFlush(change).catch(() => undefined);
  }
}
