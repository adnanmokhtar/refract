import { Body, Controller, Get, HttpCode, Param, Post, Res } from '@nestjs/common';
import { FastifyReply } from 'fastify';
import { CurrentUser, Principal } from '../common/current-user.decorator';
import { CreateOrderDto } from './dto/create-order.dto';
import { LineDto } from './dto/line.dto';
import { SearchOrdersDto } from './dto/search-orders.dto';
import { OrderDto } from './order.mapper';
import { GetOrderUseCase } from './get-order.use-case';
import { PlaceOrderUseCase } from './place-order.use-case';

@Controller('orders')
export class OrdersController {
  constructor(private readonly getOrder: GetOrderUseCase, private readonly placeOrder: PlaceOrderUseCase) {}

  @Post()
  async create(
    @CurrentUser() user: Principal,
    @Body() dto: CreateOrderDto,
    @Res({ passthrough: true }) reply: FastifyReply,
  ): Promise<OrderDto> {
    const order = await this.placeOrder.execute(user, dto);
    reply.header('Location', `/v1/orders/${order.id}`);
    return order;
  }

  @Get(':id')
  async find(@CurrentUser() user: Principal, @Param('id') id: string): Promise<OrderDto | null> {
    return this.getOrder.execute(user, id);
  }

  @Post(':id/lines')
  @HttpCode(200)
  async addLines(@Param('id') id: string, @Body() items: LineDto[]): Promise<OrderDto> {
    return this.placeOrder.addLines(id, items);
  }

  // Search is an action, not a create: 200 per the conventions.
  @Post('search')
  @HttpCode(200)
  async search(@CurrentUser() user: Principal, @Body() dto: SearchOrdersDto): Promise<OrderDto[]> {
    return this.getOrder.search(user, dto);
  }
}
