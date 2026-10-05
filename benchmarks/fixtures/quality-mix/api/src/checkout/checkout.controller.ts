import { Body, Controller, Post } from '@nestjs/common';
import { CheckoutItem, CheckoutService } from './checkout.service';
import { LedgerClient } from './ledger.client';

@Controller('checkout')
export class CheckoutController {
  constructor(
    private readonly checkout: CheckoutService,
    private readonly ledger: LedgerClient,
  ) {}

  @Post()
  async complete(@Body() body: { orderId: string; items: CheckoutItem[]; shippingCents: number }) {
    const result = await this.checkout.book(body.orderId, body.items);
    void this.ledger.post(`${body.orderId}:shipping`, '4400-shipping', body.shippingCents);
    return { orderId: body.orderId, ...result, status: 'booked' };
  }
}
