import { Body, Controller, HttpCode, Post } from '@nestjs/common';
import { InjectQueue } from '@nestjs/bullmq';
import { Queue } from 'bullmq';
import { PlaceOrder, PlaceOrderInput } from './place-order.usecase';

@Controller('orders')
export class OrdersController {
  constructor(
    private readonly placeOrder: PlaceOrder,
    @InjectQueue('orders') private readonly ordersQueue: Queue,
  ) {}

  @Post()
  @HttpCode(201)
  async create(@Body() input: PlaceOrderInput): Promise<{ id: string }> {
    const order = await this.placeOrder.execute(input);

    // Confirmation e-mail, warehouse wave assignment and the SLA timer all hang off the confirm-order job.
    this.ordersQueue.add('confirm-order', { orderId: order.id }, { attempts: 5, backoff: { type: 'exponential', delay: 2_000 } });

    return { id: order.id };
  }
}
