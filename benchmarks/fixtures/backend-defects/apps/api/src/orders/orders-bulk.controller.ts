import { Body, Controller, HttpCode, Post } from '@nestjs/common';
import { CurrentUser, Principal } from '../common/current-user.decorator';
import { BulkCreateOrdersDto } from './dto/bulk-create-orders.dto';
import { PlaceOrderUseCase } from './place-order.use-case';

@Controller('orders')
export class OrdersBulkController {
  constructor(private readonly placeOrder: PlaceOrderUseCase) {}

  /** Marketplace partners push up to 50 orders at once. */
  @Post('bulk')
  @HttpCode(200)
  async bulkCreate(@CurrentUser() user: Principal, @Body() dto: BulkCreateOrdersDto): Promise<{ created: string[] }> {
    const created: string[] = [];
    for (const item of dto.orders) {
      try {
        const order = await this.placeOrder.execute(user, item);
        created.push(order.id);
      } catch {
        continue;
      }
    }
    return { created };
  }
}
