import { BadRequestException, Controller, Param, Post } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import { Order } from '../orders/order.entity';

/** Support tool: a carrier lost the delivery scan, the customer confirms receipt on the phone. */
@Controller('admin/orders')
export class OrderRepairController {
  constructor(private readonly em: EntityManager) {}

  @Post(':id/mark-delivered')
  async markDelivered(@Param('id') id: string) {
    const order = await this.em.findOneOrFail(Order, id);
    if (order.status !== 'shipped') throw new BadRequestException('only a shipped order');
    order.status = 'delivered';
    order.deliveredAt = new Date();
    await this.em.flush();
  }
}
