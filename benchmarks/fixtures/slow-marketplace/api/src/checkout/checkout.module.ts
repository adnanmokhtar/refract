import { Module } from '@nestjs/common';
import { PspClient } from '../payments/psp.client';
import { CarrierClient } from '../shipping/carrier.client';
import { CheckoutController } from './checkout.controller';
import { CheckoutService } from './checkout.service';
import { ShippingQuotesService } from './shipping-quotes.service';

@Module({
  controllers: [CheckoutController],
  providers: [CheckoutService, ShippingQuotesService, PspClient, CarrierClient],
})
export class CheckoutModule {}
