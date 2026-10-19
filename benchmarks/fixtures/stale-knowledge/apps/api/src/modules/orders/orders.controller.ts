import { Body, Controller, Get, Param, Post, Query } from '@nestjs/common';
import { CreateOrderInput, ListOrdersQuery } from '@orderly/contracts';
import { ResponseMapper } from '../../shared/http/response.mapper';
import { PlaceOrderUseCase } from './application/place-order.use-case';
import { OrdersService } from './orders.service';

@Controller('orders')
export class OrdersController {
  constructor(
    private readonly orders: OrdersService,
    private readonly placeOrder: PlaceOrderUseCase,
    private readonly mapper: ResponseMapper,
  ) {}

  @Get()
  async list(@Query() query: ListOrdersQuery) {
    const page = await this.orders.list(query);
    return { items: page.items.map((o) => this.mapper.toResponse(o)), next: page.next };
  }

  @Get(':id')
  async findOne(@Param('id') id: string) {
    return this.mapper.toResponse(await this.orders.get(id));
  }

  @Post()
  async create(@Body() input: CreateOrderInput) {
    return this.mapper.toResponse(await this.placeOrder.execute(input));
  }
}
