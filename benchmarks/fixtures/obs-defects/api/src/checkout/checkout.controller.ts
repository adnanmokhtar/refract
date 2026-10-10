import { Body, Controller, Param, Post } from '@nestjs/common';
import { CheckoutService } from './checkout.service';

@Controller('checkout')
export class CheckoutController {
  constructor(private readonly checkout: CheckoutService) {}

  @Post()
  start(@Body() body: { cartId: string; userId: string }) {
    return this.checkout.start(body.cartId, body.userId);
  }

  @Post(':sessionId/complete')
  complete(@Param('sessionId') sessionId: string) {
    return this.checkout.complete(sessionId);
  }
}
