import { Injectable, Logger } from '@nestjs/common';
import { ORDER_ARCHIVED, ORDER_CANCELLED, ORDER_REMOVED } from './orders.events';
import { OrdersRepository } from './orders.repository';

@Injectable()
export class OrdersService {
  private readonly logger = new Logger(OrdersService.name);

  constructor(private readonly repo: OrdersRepository) {}

  list(cursor: string | undefined, limit: number) {
    return this.repo.page(cursor, limit);
  }

  find(id: string) {
    return this.repo.byId(id);
  }

  async cancel(id: string) {
    const order = await this.repo.setStatus(id, 'cancelled');
    this.repo.emit(ORDER_CANCELLED, { id });
    return order;
  }

  async archive(id: string) {
    await this.repo.setArchived(id);
    this.repo.emit(ORDER_ARCHIVED, { id });
    this.logger.log('Order archived');
    return { id, isArchived: true };
  }

  async softDelete(id: string) {
    await this.repo.setDeleted(id);
    this.repo.emit(ORDER_REMOVED, { id });
  }
}
