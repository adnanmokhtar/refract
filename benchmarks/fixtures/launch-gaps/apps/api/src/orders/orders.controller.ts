import { Body, Controller, Get, Param, Post, Query } from '@nestjs/common';
import { RequireModule } from '../entitlements/require-module.decorator';
import { OrdersService } from './orders.service';

@RequireModule('orders')
@Controller('orders')
export class OrdersController {
  constructor(private readonly orders: OrdersService) {}

  @Get()
  list(@Query('q') q?: string, @Query('cursor') cursor?: string) {
    return this.orders.list({ q, cursor });
  }

  @Post()
  create(@Body() draft: { lines: { sku: string; qty: number }[]; customerId?: string }) {
    return this.orders.createManual(draft);
  }

  @Get(':id')
  get(@Param('id') id: string) {
    return this.orders.get(id);
  }

  /** The PDF receipt (renamed from /invoice in 2026-08; the PDF is the same). */
  @Get(':id/receipt')
  receipt(@Param('id') id: string) {
    return this.orders.receiptPdf(id);
  }

  @Post(':id/refunds')
  refund(@Param('id') id: string, @Body() body: { lines: string[]; reason: string }) {
    return this.orders.refund(id, body);
  }
}
