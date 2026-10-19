import { Controller, Get, HttpCode, Param, ParseIntPipe, Patch, Post, Res } from '@nestjs/common';
import { CreateOrderBody, type CreateOrderBodyT, OrderListQuery, type OrderListQueryT, UpdateOrderBody, type UpdateOrderBodyT } from '@norrow/contracts';
import type { FastifyReply } from 'fastify';
import { type AuthUser, CurrentUser } from '../common/current-user.decorator';
import { Permissions } from '../common/permissions.decorator';
import { ZodBody, ZodQuery } from '../common/zod';
import { OrdersService } from './orders.service';

@Controller('orders')
export class OrdersController {
  constructor(private readonly orders: OrdersService) {}

  @Get()
  @Permissions('orders:view')
  list(@ZodQuery(OrderListQuery) query: OrderListQueryT) {
    return this.orders.list(query);
  }

  @Post()
  @Permissions('orders:create')
  @HttpCode(201)
  create(@ZodBody(CreateOrderBody) body: CreateOrderBodyT, @CurrentUser() user: AuthUser) {
    return this.orders.create(body, user);
  }

  @Get('export')
  @Permissions('orders:export')
  async export(@Res() reply: FastifyReply) {
    const csv = await this.orders.exportCsv();
    void reply.header('content-type', 'text/csv').header('content-disposition', 'attachment; filename="orders.csv"').send(csv);
  }

  @Get(':id')
  @Permissions('orders:view')
  get(@Param('id', ParseIntPipe) id: number) {
    return this.orders.get(id);
  }

  @Patch(':id')
  @Permissions('orders:update')
  update(@Param('id', ParseIntPipe) id: number, @ZodBody(UpdateOrderBody) body: UpdateOrderBodyT) {
    return this.orders.update(id, body);
  }

  @Post(':id/cancel')
  @Permissions('orders:update')
  @HttpCode(200)
  cancel(@Param('id', ParseIntPipe) id: number) {
    return this.orders.cancel(id);
  }
}
