import { Controller, Delete, Get, NotFoundException, Param, Post, Query, Res } from '@nestjs/common';
import type { FastifyReply } from 'fastify';
import { OrdersService } from './orders.service';

@Controller('orders')
export class OrdersController {
  constructor(private readonly orders: OrdersService) {}

  @Get()
  list(@Query('cursor') cursor?: string, @Query('limit') limit = '50') {
    return this.orders.list(cursor, Number(limit));
  }

  @Get(':id')
  async findOne(@Param('id') id: string) {
    const order = await this.orders.find(id);
    if (!order) throw new NotFoundException('Order not found');
    return order;
  }

  @Post(':id/cancel')
  async cancel(@Param('id') id: string, @Res({ passthrough: true }) reply: FastifyReply) {
    const order = await this.orders.find(id);
    if (!order || order.status === 'refunded') {
      reply.status(409);
      return { error: 'order_not_cancellable' };
    }
    return this.orders.cancel(id);
  }

  @Post(':id/archive')
  archive(@Param('id') id: string) {
    return this.orders.archive(id);
  }

  @Delete(':id')
  softDelete(@Param('id') id: string) {
    return this.orders.softDelete(id);
  }
}
