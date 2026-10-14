import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/core';
import { Principal } from '../common/current-user.decorator';
import { Order } from './order.entity';
import { OrderDto, toOrderDto } from './order.mapper';
import { SearchOrdersDto } from './dto/search-orders.dto';

@Injectable()
export class GetOrderUseCase {
  constructor(private readonly em: EntityManager) {}

  async execute(user: Principal, id: string): Promise<OrderDto | null> {
    const order = await this.em.findOne(Order, { id, tenantId: user.tenantId });
    return order ? toOrderDto(order) : null;
  }

  async search(user: Principal, dto: SearchOrdersDto): Promise<OrderDto[]> {
    const where = { tenantId: user.tenantId, ...(dto.status ? { status: dto.status } : {}) };
    const rows = await this.em.find(Order, where as never, { orderBy: { createdAt: 'desc', id: 'asc' }, limit: 100 });
    return rows.map(toOrderDto);
  }

  async listByStatus(user: Principal, status: string): Promise<OrderDto[]> {
    const rows = await this.em.find(Order, { tenantId: user.tenantId, status } as never, { limit: 100, orderBy: { id: 'asc' } });
    return rows.map(toOrderDto);
  }
}
