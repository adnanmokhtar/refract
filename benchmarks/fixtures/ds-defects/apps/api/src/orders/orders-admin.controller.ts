import { Body, Controller, Post, Res } from '@nestjs/common';
import { CommandBus } from '@nestjs/cqrs';
import { FastifyReply } from 'fastify';
import { BulkCancelOrdersCommand } from './bulk-cancel-orders.command';

/**
 * Admin console (server-rendered). The order list at /admin/orders reads order_summary, the read model the
 * worker's order-summary projector maintains from the order streams.
 */
@Controller('admin/orders')
export class OrdersAdminController {
  constructor(private readonly commandBus: CommandBus) {}

  @Post('bulk-cancel')
  async bulkCancel(@Body() body: { orderIds: string[]; reason: string }, @Res() reply: FastifyReply): Promise<void> {
    await this.commandBus.execute(new BulkCancelOrdersCommand(body.orderIds, body.reason));
    return reply.redirect('/admin/orders?cancelled=1', 303);
  }
}
