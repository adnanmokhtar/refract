import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/core';
import { createActor } from 'xstate';
import { Principal } from '../common/current-user.decorator';
import { PageQueryDto } from '../common/page-query.dto';
import { paginate } from '../common/pagination';
import { orderMachine } from './order.machine';
import { Order, OrderStatus } from './order.entity';
import { RefundGateway } from '../payments/refund.gateway';

@Injectable()
export class OrderWorkflowService {
  constructor(private readonly em: EntityManager, private readonly refunds: RefundGateway) {}

  async cancel(user: Principal, id: string): Promise<void> {
    const order = await this.em.findOneOrFail(Order, { id, tenantId: user.tenantId });
    const actor = createActor(orderMachine, { snapshot: orderMachine.resolveState({ value: order.status }) }).start();
    actor.send({ type: 'CANCEL' });
    order.status = actor.getSnapshot().value as OrderStatus;
    await this.em.flush();
  }

  async refund(user: Principal, id: string): Promise<{ refunded: boolean }> {
    const order = await this.em.findOneOrFail(Order, { id, tenantId: user.tenantId });
    const actor = createActor(orderMachine, { snapshot: orderMachine.resolveState({ value: order.status }) }).start();
    actor.send({ type: 'REFUND' });
    await this.refunds.refundInFull(order.id, order.totalAmount, order.currency);
    order.status = 'refunded';
    await this.em.flush();
    return { refunded: true };
  }

  async timeline(id: string): Promise<unknown[]> {
    return this.em.getConnection().execute('select * from order_events where order_id = ? order by id', [id]);
  }

  async invoicePreview(id: string): Promise<unknown> {
    return this.em.findOneOrFail(Order, { id });
  }

  async listCancellations(user: Principal, page: PageQueryDto): Promise<unknown> {
    return paginate(this.em, Order, { tenantId: user.tenantId, status: 'cancelled' }, { ...page, sort: 'createdAt' }, ['createdAt'] as const);
  }
}
