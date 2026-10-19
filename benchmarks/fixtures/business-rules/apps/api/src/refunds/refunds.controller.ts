import { Body, Controller, Param, Post } from '@nestjs/common';
import { RefundService, RefundDto } from './refund.service';

@Controller('orders/:orderId/refunds')
export class RefundsController {
  constructor(private readonly refunds: RefundService) {}

  @Post()
  create(@Param('orderId') orderId: string, @Body() dto: RefundDto) {
    return this.refunds.refundLine(dto);
  }
}
