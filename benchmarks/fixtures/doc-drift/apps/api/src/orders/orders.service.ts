import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';

import type { CreateOrderDto } from './dto/create-order.dto';
import { OrdersRepository, type Order } from './orders.repository';

@Injectable()
export class OrdersService {
  constructor(private readonly repo: OrdersRepository) {}

  list(cursor: string | undefined, limit = 20) {
    return this.repo.page({ cursor, limit: Math.min(limit, 100) });
  }

  create(input: CreateOrderDto): Promise<Order> {
    return this.repo.insert(input);
  }

  async get(id: string): Promise<Order> {
    const order = await this.repo.find(id);
    if (!order) throw new NotFoundException(`order ${id} not found`);
    return order;
  }

  async cancel(id: string): Promise<Order> {
    const order = await this.get(id);
    if (order.status === 'cancelled') throw new ConflictException(`order ${id} is already cancelled`);
    if (order.status === 'paid') throw new ConflictException(`order ${id} is paid: refund it instead`);
    return this.repo.setStatus(id, 'cancelled');
  }

  exportCsv(): Promise<string> {
    return this.repo.exportCsv();
  }
}
