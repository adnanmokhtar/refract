import { Body, Controller, Get, Param, Post, Query, Req } from '@nestjs/common';
import { AuthUser } from '../auth/auth-user';
import { CartDto, CheckoutService } from './checkout.service';
import { QuoteCartDto, ShippingQuotesService } from './shipping-quotes.service';

@Controller()
export class CheckoutController {
  constructor(
    private readonly checkout: CheckoutService,
    private readonly quotes: ShippingQuotesService,
  ) {}

  @Post('checkout')
  place(@Req() req: { user: AuthUser }, @Body() cart: CartDto) {
    return this.checkout.placeOrder(req.user, cart);
  }

  @Post('checkout/quotes')
  quote(@Body() cart: QuoteCartDto) {
    return this.quotes.quoteCart(cart);
  }

  @Get('checkout/pickup-windows')
  windows(@Query('warehouses') warehouses: string, @Query('day') day: string) {
    return this.quotes.pickupWindows(warehouses.split(',').slice(0, 50), day);
  }

  @Post('orders/:id/cancel')
  cancel(@Req() req: { user: AuthUser }, @Param('id') id: string) {
    return this.checkout.cancel(id, req.user);
  }
}
