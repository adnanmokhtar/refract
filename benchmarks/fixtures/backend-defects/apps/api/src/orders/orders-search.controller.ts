import { Controller, Get, Query } from '@nestjs/common';
import { CurrentUser, Principal } from '../common/current-user.decorator';
import { GetOrderUseCase } from './get-order.use-case';

@Controller('orders')
export class OrdersSearchController {
  constructor(private readonly getOrder: GetOrderUseCase) {}

  @Get()
  async list(@CurrentUser() user: Principal, @Query('status') status: string): Promise<unknown> {
    return this.getOrder.listByStatus(user, status);
  }
}
