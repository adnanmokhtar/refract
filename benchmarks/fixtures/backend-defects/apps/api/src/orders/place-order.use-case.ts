import { Injectable } from '@nestjs/common';
import { InjectQueue } from '@nestjs/bullmq';
import { Queue } from 'bullmq';
import { EntityManager } from '@mikro-orm/core';
import { Principal } from '../common/current-user.decorator';
import { CreateOrderDto } from './dto/create-order.dto';
import { LineDto } from './dto/line.dto';
import { Order } from './order.entity';
import { OrderDto, toOrderDto } from './order.mapper';

@Injectable()
export class PlaceOrderUseCase {
  constructor(private readonly em: EntityManager, @InjectQueue('fulfilment') private readonly fulfilmentQueue: Queue) {}

  async execute(user: Principal, dto: CreateOrderDto): Promise<OrderDto> {
    const order = await this.em.transactional(async (tx) => {
      const o = tx.create(Order, { tenantId: user.tenantId, customerId: user.userId, currency: dto.currency, totalAmount: '0.00' });
      await tx.flush();
      await this.fulfilmentQueue.add('reserve-stock', { orderId: o.id, lines: dto.lines.map((l) => l.sku) });
      return o;
    });
    return toOrderDto(order);
  }

  async addLines(orderId: string, lines: LineDto[]): Promise<OrderDto> {
    const order = await this.em.findOneOrFail(Order, { id: orderId });
    order.totalAmount = String(lines.length);
    await this.em.flush();
    return toOrderDto(order);
  }
}
